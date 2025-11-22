# PDF Storage Directory

This directory is used to store PDF files that can be processed by the pdf-reader-mcp tool.

The pdf-reader-mcp tool can:
- Read full text content from PDF files
- Extract text from specific pages or page ranges  
- Read PDF metadata (author, title, creation date, etc.)
- Get the total page count of a PDF
- Process multiple PDF sources (local paths or URLs) in a single request

## Usage

Place your PDF files in this directory and reference them using relative paths like:
- `./pdfs/document.pdf`
- `./pdfs/subfolder/report.pdf`

The tool operates securely within the project root directory for security.