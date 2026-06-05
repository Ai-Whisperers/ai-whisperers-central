/**
 * Install Command - Register Launch with Claude Code CLI
 */

import chalk from "chalk";
import ora from "ora";
import { existsSync, copyFileSync } from "fs";
import {
  getClaudeCodeSettingsPath,
  getClaudeDesktopConfigPath,
  readClaudeSettings,
  writeClaudeSettings,
  isLaunchRegistered,
  registerLaunch,
  unregisterLaunch,
} from "../utils/config.js";

interface InstallOptions {
  includeDesktop?: boolean;
}

/**
 * Install Launch MCP server
 */
export async function install(options: InstallOptions): Promise<void> {
  const spinner = ora("Installing Launch MCP server").start();

  try {
    // Primary: Claude Code CLI
    const claudeCodePath = getClaudeCodeSettingsPath();
    spinner.text = `Checking Claude Code settings at ${claudeCodePath}`;

    let settings = readClaudeSettings(claudeCodePath);

    if (isLaunchRegistered(settings)) {
      spinner.warn("Launch is already registered with Claude Code CLI");
    } else {
      // Backup existing settings
      if (existsSync(claudeCodePath)) {
        const backupPath = claudeCodePath.replace(".json", ".backup.json");
        copyFileSync(claudeCodePath, backupPath);
        spinner.text = `Backed up existing settings to ${backupPath}`;
      }

      settings = registerLaunch(settings);
      writeClaudeSettings(claudeCodePath, settings);
      spinner.succeed(
        chalk.green("Launch registered with Claude Code CLI")
      );
    }

    // Optional: Claude Desktop
    if (options.includeDesktop) {
      const desktopPath = getClaudeDesktopConfigPath();
      if (desktopPath) {
        spinner.start("Registering with Claude Desktop");
        let desktopSettings = readClaudeSettings(desktopPath);

        if (isLaunchRegistered(desktopSettings)) {
          spinner.warn("Launch is already registered with Claude Desktop");
        } else {
          if (existsSync(desktopPath)) {
            const backupPath = desktopPath.replace(".json", ".backup.json");
            copyFileSync(desktopPath, backupPath);
          }

          desktopSettings = registerLaunch(desktopSettings);
          writeClaudeSettings(desktopPath, desktopSettings);
          spinner.succeed(
            chalk.green("Launch registered with Claude Desktop")
          );
        }
      } else {
        spinner.warn("Claude Desktop config path not found for this platform");
      }
    }

    // Final instructions
    console.log("");
    console.log(chalk.cyan("Installation complete!"));
    console.log("");
    console.log("To use Launch with Claude Code:");
    console.log(
      chalk.dim("  1. Restart Claude Code CLI if it's running")
    );
    console.log(
      chalk.dim('  2. Ask Claude to "deploy my project" or "analyze for deployment"')
    );
    console.log("");
    console.log(
      chalk.dim("Run 'launch doctor' to verify the installation")
    );
  } catch (error) {
    spinner.fail(chalk.red("Installation failed"));
    console.error(error);
    process.exit(1);
  }
}

/**
 * Uninstall Launch MCP server
 */
export async function uninstall(options: InstallOptions): Promise<void> {
  const spinner = ora("Uninstalling Launch MCP server").start();

  try {
    // Primary: Claude Code CLI
    const claudeCodePath = getClaudeCodeSettingsPath();
    let settings = readClaudeSettings(claudeCodePath);

    if (!isLaunchRegistered(settings)) {
      spinner.warn("Launch is not registered with Claude Code CLI");
    } else {
      settings = unregisterLaunch(settings);
      writeClaudeSettings(claudeCodePath, settings);
      spinner.succeed(chalk.green("Launch removed from Claude Code CLI"));
    }

    // Optional: Claude Desktop
    if (options.includeDesktop) {
      const desktopPath = getClaudeDesktopConfigPath();
      if (desktopPath && existsSync(desktopPath)) {
        spinner.start("Removing from Claude Desktop");
        let desktopSettings = readClaudeSettings(desktopPath);

        if (!isLaunchRegistered(desktopSettings)) {
          spinner.warn("Launch is not registered with Claude Desktop");
        } else {
          desktopSettings = unregisterLaunch(desktopSettings);
          writeClaudeSettings(desktopPath, desktopSettings);
          spinner.succeed(chalk.green("Launch removed from Claude Desktop"));
        }
      }
    }

    console.log("");
    console.log(chalk.cyan("Uninstallation complete"));
  } catch (error) {
    spinner.fail(chalk.red("Uninstallation failed"));
    console.error(error);
    process.exit(1);
  }
}
