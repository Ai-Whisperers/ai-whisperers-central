#!/usr/bin/env node
/**
 * Launch CLI - Command line interface for Launch MCP
 *
 * Commands:
 * - install: Register Launch with Claude Code CLI
 * - uninstall: Remove Launch from Claude Code CLI
 * - doctor: Check system requirements
 * - serve: Run the MCP server manually
 * - version: Show version information
 */

import { Command } from "commander";
import { VERSION, NAME, DESCRIPTION } from "../utils/version.js";
import { install, uninstall } from "./install.js";
import { doctor } from "./doctor.js";
import { serve } from "./serve.js";

const program = new Command();

program
  .name(NAME)
  .description(DESCRIPTION)
  .version(VERSION, "-v, --version", "Show version number");

program
  .command("install")
  .description("Register Launch MCP server with Claude Code CLI")
  .option("--desktop", "Also register with Claude Desktop")
  .action(async (options) => {
    await install({ includeDesktop: options.desktop });
  });

program
  .command("uninstall")
  .description("Remove Launch MCP server from Claude Code CLI")
  .option("--desktop", "Also remove from Claude Desktop")
  .action(async (options) => {
    await uninstall({ includeDesktop: options.desktop });
  });

program
  .command("doctor")
  .description("Check system requirements and configuration")
  .option("--verbose", "Show detailed information")
  .action(async (options) => {
    await doctor({ verbose: options.verbose });
  });

program
  .command("serve")
  .description("Run the MCP server manually (for debugging)")
  .action(async () => {
    await serve();
  });

program.parse();
