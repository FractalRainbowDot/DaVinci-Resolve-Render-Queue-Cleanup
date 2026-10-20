# DaVinci Resolve 20 — Render Queue Cleanup

A small Windows GUI utility for removing accumulated `Batch Renders` folders from **local (disk-based)** DaVinci Resolve project libraries.

## Why?

In one local library containing many projects, opening the **Deliver** page became extremely slow. Temporarily isolating `Batch Renders` folders made Deliver responsive again. This tool allows you to locate and delete those folders for a selected library. This is a community workaround, **not an official Blackmagic Design utility**. Results may vary.

## Requirements

- Windows 10/11
- Windows PowerShell 5.1
- DaVinci Resolve 20 (tested by the original user)
- Local disk-based project library containing `Resolve Projects/Users`

## Usage

1. **Back up your project library** using Resolve before proceeding.
2. Close DaVinci Resolve completely.
3. Download/extract the repository contents.
4. Double-click `Start_Cleanup.bat`.
5. Paste the full path of your `Resolve Projects` folder, or click **Browse...**.
6. Click **Scan** and check the count.
7. Click **Delete Batch Renders** and confirm the deletion.
8. Reopen Resolve and check Deliver.

Example path: `S:\Projects\library_2026\Resolve Projects`

## What gets deleted?

Directories named exactly `Batch Renders` under the selected library's `Users` tree, along with their contents. These may contain previously saved render jobs / queue history.

The utility does **not intentionally target** `Project.db` or media files, but deleting any data from project directories has inherent risk. This is **permanent deletion**, not a Recycle Bin operation, and there is no built-in undo.

Folders renamed by earlier isolation experiments are **not** selected.

## Safety design

- Requires selecting a `Resolve Projects` directory with a `Users` subfolder.
- Scans before enabling deletion.
- Blocks deletion when `Resolve` process is running.
- Displays a confirmation dialog.
- Restricts deletion targets to the exact folder name `Batch Renders` and checks target paths.

**Important:** Only use on a library that you own and have backed up. Review the PowerShell source before execution. This script has not been independently audited, and is not guaranteed to work with other versions or network/PostgreSQL libraries.

## Files

- `Start_Cleanup.bat` — double-click launcher.
- `Resolve20_Cleanup.ps1` — Windows Forms GUI and cleanup logic.

## License

MIT — see `LICENSE`.
