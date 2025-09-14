#!/usr/bin/env python3
"""
Convert PDF to Markdown
Converts inst/docs/docX13AS.pdf to Markdown format
"""

import sys
import os
from pathlib import Path

# Try different PDF libraries
try:
    import pymupdf4llm
    USE_PYMUPDF4LLM = True
except ImportError:
    USE_PYMUPDF4LLM = False

try:
    import pdfplumber
    USE_PDFPLUMBER = True
except ImportError:
    USE_PDFPLUMBER = False

try:
    import PyPDF2
    USE_PYPDF2 = True
except ImportError:
    USE_PYPDF2 = False

def convert_with_pymupdf4llm(pdf_path, output_path):
    """Convert PDF to Markdown using pymupdf4llm (best quality)"""
    import pymupdf4llm

    print(f"Converting with pymupdf4llm...")
    md_text = pymupdf4llm.to_markdown(pdf_path)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(md_text)

    print(f"✓ Converted to {output_path}")

def convert_with_pdfplumber(pdf_path, output_path):
    """Convert PDF to Markdown using pdfplumber"""
    import pdfplumber

    print(f"Converting with pdfplumber...")
    md_content = []

    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages, 1):
            md_content.append(f"## Page {page_num}\n")

            # Extract text
            text = page.extract_text()
            if text:
                # Basic formatting - paragraphs
                paragraphs = text.split('\n\n')
                for para in paragraphs:
                    # Clean up whitespace
                    para = ' '.join(para.split())
                    if para:
                        md_content.append(para + '\n')

            # Extract tables if any
            tables = page.extract_tables()
            for table in tables:
                if table:
                    md_content.append('\n')
                    # Convert table to markdown
                    for row_idx, row in enumerate(table):
                        row_str = '| ' + ' | '.join(str(cell or '') for cell in row) + ' |'
                        md_content.append(row_str)
                        if row_idx == 0:
                            # Add header separator
                            sep = '|' + '|'.join(['---' for _ in row]) + '|'
                            md_content.append(sep)
                    md_content.append('\n')

            md_content.append('\n---\n\n')

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(md_content))

    print(f"✓ Converted to {output_path}")

def convert_with_pypdf2(pdf_path, output_path):
    """Convert PDF to Markdown using PyPDF2 (basic text extraction)"""
    import PyPDF2

    print(f"Converting with PyPDF2...")
    md_content = []

    with open(pdf_path, 'rb') as file:
        pdf_reader = PyPDF2.PdfReader(file)
        num_pages = len(pdf_reader.pages)

        for page_num in range(num_pages):
            page = pdf_reader.pages[page_num]
            md_content.append(f"## Page {page_num + 1}\n")

            text = page.extract_text()
            # Basic paragraph formatting
            paragraphs = text.split('\n\n')
            for para in paragraphs:
                para = ' '.join(para.split())
                if para:
                    md_content.append(para + '\n')

            md_content.append('\n---\n\n')

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(md_content))

    print(f"✓ Converted to {output_path}")

def main():
    # Define paths
    pdf_path = Path("inst/docs/docX13AS.pdf")
    output_path = Path("inst/docs/docX13AS.md")

    # Check if PDF exists
    if not pdf_path.exists():
        print(f"Error: PDF file not found at {pdf_path}")
        sys.exit(1)

    print(f"Converting {pdf_path} to Markdown...")
    print(f"Output will be saved to {output_path}")
    print()

    # Check available libraries and convert
    if USE_PYMUPDF4LLM:
        print("Using pymupdf4llm (recommended for best quality)")
        try:
            convert_with_pymupdf4llm(str(pdf_path), str(output_path))
            return
        except Exception as e:
            print(f"pymupdf4llm failed: {e}")

    if USE_PDFPLUMBER:
        print("Using pdfplumber")
        try:
            convert_with_pdfplumber(str(pdf_path), str(output_path))
            return
        except Exception as e:
            print(f"pdfplumber failed: {e}")

    if USE_PYPDF2:
        print("Using PyPDF2 (basic text extraction)")
        try:
            convert_with_pypdf2(str(pdf_path), str(output_path))
            return
        except Exception as e:
            print(f"PyPDF2 failed: {e}")

    # No libraries available
    print("\nNo PDF libraries found. Please install one of the following:")
    print("  pip install pymupdf4llm  # Best quality, recommended")
    print("  pip install pdfplumber   # Good for tables")
    print("  pip install PyPDF2       # Basic text extraction")
    sys.exit(1)

if __name__ == "__main__":
    main()