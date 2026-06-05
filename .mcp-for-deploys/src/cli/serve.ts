/**
 * Serve Command - Run the MCP server manually
 *
 * Useful for debugging and testing the server directly.
 */

import chalk from "chalk";
import { VERSION } from "../utils/version.js";

/**
 * Run the MCP server
 */
export async function serve(): Promise<void> {
  console.error(chalk.cyan(`Launch MCP Server v${VERSION}`));
  console.error(chalk.dim("Running in stdio mode..."));
  console.error(chalk.dim("Press Ctrl+C to stop\n"));

  // Dynamically import and run the main server
  // This allows the server to take over stdio
  await import("../index.js");
}
