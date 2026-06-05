# Export Interface Contract

**Status:** Defined
**Date:** 2025-12-15
**Covers Gap:** #4 - Export Interface Detail

---

## Overview

The export system uses two separate interfaces:
1. **IExportFormat** - Serializes Arrow tables to bytes (Parquet, CSV, JSON)
2. **IExportDestination** - Writes bytes to storage (Local, S3, R2, GDrive, etc.)

This separation allows mixing any format with any destination.

---

## Interface Definitions

### IExportFormat

```python
from abc import ABC, abstractmethod
from typing import BinaryIO
import pyarrow as pa

class IExportFormat(ABC):
    """Converts Arrow tables to a specific file format."""

    @property
    @abstractmethod
    def format_id(self) -> str:
        """Unique identifier: 'parquet', 'csv', 'json'"""
        pass

    @property
    @abstractmethod
    def file_extension(self) -> str:
        """File extension including dot: '.parquet', '.csv', '.json'"""
        pass

    @property
    @abstractmethod
    def mime_type(self) -> str:
        """MIME type for HTTP responses"""
        pass

    @abstractmethod
    def serialize(self, table: pa.Table, stream: BinaryIO) -> int:
        """
        Serialize Arrow table to output stream.

        Args:
            table: PyArrow Table to serialize
            stream: Binary stream to write to

        Returns:
            Number of bytes written
        """
        pass

    @abstractmethod
    def get_config(self) -> dict:
        """Return format-specific configuration for reproducibility."""
        pass
```

### IExportDestination

```python
from abc import ABC, abstractmethod
from typing import BinaryIO, Optional
from dataclasses import dataclass

@dataclass
class ExportResult:
    """Result of an export operation."""
    success: bool
    location: str          # URI or path where data was written
    bytes_written: int
    checksum: Optional[str]  # SHA256 if computed
    error: Optional[str]

class IExportDestination(ABC):
    """Writes data to a storage destination."""

    @property
    @abstractmethod
    def destination_id(self) -> str:
        """Unique identifier: 'local', 's3', 'r2', 'gcs', 'gdrive'"""
        pass

    @abstractmethod
    def write(
        self,
        data: BinaryIO,
        path: str,
        content_type: str,
        metadata: Optional[dict] = None
    ) -> ExportResult:
        """
        Write data to destination.

        Args:
            data: Binary stream to read from
            path: Destination path/key (format-agnostic)
            content_type: MIME type of data
            metadata: Optional metadata to attach

        Returns:
            ExportResult with location and status
        """
        pass

    @abstractmethod
    def exists(self, path: str) -> bool:
        """Check if path already exists."""
        pass

    @abstractmethod
    def delete(self, path: str) -> bool:
        """Delete file at path. Returns True if deleted."""
        pass

    @abstractmethod
    def list_files(self, prefix: str) -> list[str]:
        """List files matching prefix."""
        pass

    @abstractmethod
    def get_uri(self, path: str) -> str:
        """Get full URI for a path (file://, s3://, etc.)"""
        pass
```

---

## Format Implementations

### ParquetFormat

```python
class ParquetFormat(IExportFormat):
    format_id = "parquet"
    file_extension = ".parquet"
    mime_type = "application/vnd.apache.parquet"

    def __init__(self, compression: str = "zstd", row_group_size: int = 100_000):
        self.compression = compression
        self.row_group_size = row_group_size

    def serialize(self, table: pa.Table, stream: BinaryIO) -> int:
        import pyarrow.parquet as pq
        pq.write_table(
            table,
            stream,
            compression=self.compression,
            row_group_size=self.row_group_size
        )
        return stream.tell()

    def get_config(self) -> dict:
        return {
            "compression": self.compression,
            "row_group_size": self.row_group_size
        }
```

### CSVFormat

```python
class CSVFormat(IExportFormat):
    format_id = "csv"
    file_extension = ".csv"
    mime_type = "text/csv"

    def __init__(self, delimiter: str = ",", include_header: bool = True):
        self.delimiter = delimiter
        self.include_header = include_header

    def serialize(self, table: pa.Table, stream: BinaryIO) -> int:
        import pyarrow.csv as csv
        csv.write_csv(
            table,
            stream,
            write_options=csv.WriteOptions(
                delimiter=self.delimiter,
                include_header=self.include_header
            )
        )
        return stream.tell()

    def get_config(self) -> dict:
        return {
            "delimiter": self.delimiter,
            "include_header": self.include_header
        }
```

### JSONFormat

```python
class JSONFormat(IExportFormat):
    format_id = "json"
    file_extension = ".json"
    mime_type = "application/json"

    def __init__(self, orient: str = "records", lines: bool = True):
        self.orient = orient  # 'records' or 'columns'
        self.lines = lines    # JSON Lines format (one record per line)

    def serialize(self, table: pa.Table, stream: BinaryIO) -> int:
        import json
        df = table.to_pandas()

        if self.lines and self.orient == "records":
            for record in df.to_dict(orient="records"):
                stream.write(json.dumps(record).encode() + b"\n")
        else:
            data = df.to_dict(orient=self.orient)
            stream.write(json.dumps(data, ensure_ascii=False).encode())

        return stream.tell()

    def get_config(self) -> dict:
        return {"orient": self.orient, "lines": self.lines}
```

---

## Destination Implementations

### LocalDestination

```python
from pathlib import Path

class LocalDestination(IExportDestination):
    destination_id = "local"

    def __init__(self, base_path: str = "./exports"):
        self.base_path = Path(base_path)
        self.base_path.mkdir(parents=True, exist_ok=True)

    def write(self, data, path, content_type, metadata=None) -> ExportResult:
        full_path = self.base_path / path
        full_path.parent.mkdir(parents=True, exist_ok=True)

        with open(full_path, "wb") as f:
            content = data.read()
            f.write(content)

        return ExportResult(
            success=True,
            location=str(full_path.absolute()),
            bytes_written=len(content),
            checksum=None,
            error=None
        )

    def get_uri(self, path: str) -> str:
        return f"file://{self.base_path / path}"
```

### S3Destination (S3-Compatible: AWS, R2, MinIO, etc.)

```python
class S3Destination(IExportDestination):
    destination_id = "s3"

    def __init__(
        self,
        bucket: str,
        endpoint_url: str = None,  # For R2, MinIO, etc.
        region: str = "auto",
        access_key: str = None,
        secret_key: str = None
    ):
        self.bucket = bucket
        self.endpoint_url = endpoint_url
        self.region = region
        # Credentials from params or environment
        self._init_client(access_key, secret_key)

    def _init_client(self, access_key, secret_key):
        import boto3
        self.client = boto3.client(
            "s3",
            endpoint_url=self.endpoint_url,
            region_name=self.region,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key
        )

    def write(self, data, path, content_type, metadata=None) -> ExportResult:
        content = data.read()
        self.client.put_object(
            Bucket=self.bucket,
            Key=path,
            Body=content,
            ContentType=content_type,
            Metadata=metadata or {}
        )
        return ExportResult(
            success=True,
            location=self.get_uri(path),
            bytes_written=len(content),
            checksum=None,
            error=None
        )

    def get_uri(self, path: str) -> str:
        if self.endpoint_url:
            return f"{self.endpoint_url}/{self.bucket}/{path}"
        return f"s3://{self.bucket}/{path}"
```

### GoogleDriveDestination (Stub)

```python
class GoogleDriveDestination(IExportDestination):
    """
    Google Drive export destination.
    Requires: google-api-python-client, google-auth
    """
    destination_id = "gdrive"

    def __init__(self, folder_id: str, credentials_path: str = None):
        self.folder_id = folder_id
        self._init_service(credentials_path)

    def write(self, data, path, content_type, metadata=None) -> ExportResult:
        from googleapiclient.http import MediaIoBaseUpload

        media = MediaIoBaseUpload(data, mimetype=content_type)
        file_metadata = {"name": path, "parents": [self.folder_id]}

        result = self.service.files().create(
            body=file_metadata,
            media_body=media,
            fields="id,webViewLink"
        ).execute()

        return ExportResult(
            success=True,
            location=result.get("webViewLink"),
            bytes_written=data.tell(),
            checksum=None,
            error=None
        )

    def get_uri(self, path: str) -> str:
        return f"gdrive://{self.folder_id}/{path}"
```

---

## Exporter Orchestrator

Combines format + destination:

```python
class Exporter:
    """High-level export orchestrator."""

    def __init__(
        self,
        format: IExportFormat,
        destination: IExportDestination
    ):
        self.format = format
        self.destination = destination

    def export(
        self,
        table: pa.Table,
        name: str,
        metadata: Optional[dict] = None
    ) -> ExportResult:
        """
        Export Arrow table to destination.

        Args:
            table: PyArrow Table to export
            name: Base filename (extension added automatically)
            metadata: Optional metadata to attach

        Returns:
            ExportResult with location info
        """
        import io

        # Generate filename
        filename = f"{name}{self.format.file_extension}"

        # Serialize to buffer
        buffer = io.BytesIO()
        self.format.serialize(table, buffer)
        buffer.seek(0)

        # Write to destination
        return self.destination.write(
            data=buffer,
            path=filename,
            content_type=self.format.mime_type,
            metadata=metadata
        )
```

---

## Usage Examples

```python
# Local Parquet export
exporter = Exporter(
    format=ParquetFormat(compression="zstd"),
    destination=LocalDestination("./output")
)
result = exporter.export(analysis_table, "feedback_analysis_2025_01")
# -> file://./output/feedback_analysis_2025_01.parquet

# Cloudflare R2 CSV export
exporter = Exporter(
    format=CSVFormat(),
    destination=S3Destination(
        bucket="my-bucket",
        endpoint_url="https://xyz.r2.cloudflarestorage.com"
    )
)
result = exporter.export(analysis_table, "exports/daily/2025-01-15")
# -> https://xyz.r2.cloudflarestorage.com/my-bucket/exports/daily/2025-01-15.csv

# Google Drive JSON export
exporter = Exporter(
    format=JSONFormat(lines=True),
    destination=GoogleDriveDestination(folder_id="abc123")
)
result = exporter.export(analysis_table, "weekly_report")
# -> gdrive://abc123/weekly_report.json
```

---

## Extending

To add a new destination:
1. Implement `IExportDestination` interface
2. Add to destination registry
3. Document credential requirements

To add a new format:
1. Implement `IExportFormat` interface
2. Add to format registry
3. Ensure Arrow table compatibility

---

## Configuration

```json
{
  "export": {
    "default_format": "parquet",
    "default_destination": "local",
    "destinations": {
      "local": {
        "base_path": "./exports"
      },
      "s3": {
        "bucket": "feedback-exports",
        "endpoint_url": null,
        "region": "us-east-1"
      },
      "r2": {
        "bucket": "feedback-exports",
        "endpoint_url": "https://xxx.r2.cloudflarestorage.com"
      }
    },
    "formats": {
      "parquet": {"compression": "zstd"},
      "csv": {"delimiter": ","},
      "json": {"lines": true}
    }
  }
}
```

---

**Next:** Gap 5 - Project Scaffolding
