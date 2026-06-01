#!/usr/bin/env python3
"""Generate a well-formatted PDF from the AI Photographer PRD markdown."""

from fpdf import FPDF
import re

class PRDPdf(FPDF):
    def header(self):
        if self.page_no() > 1:
            self.set_font("Helvetica", "I", 8)
            self.set_text_color(128, 128, 128)
            self.cell(0, 5, "AI Photographer - PRD + Implementation Plan", align="R")
            self.ln(8)
            self.set_text_color(0, 0, 0)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(128, 128, 128)
        self.cell(0, 10, f"Page {self.page_no()}", align="C")

def safe(text):
    """Replace problematic characters for latin-1 encoding."""
    replacements = {
        "\u2014": "--",  # em dash
        "\u2013": "-",   # en dash
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u2026": "...",
        "\u00b0": " deg",
        "\u2022": "-",
        "\u00d7": "x",
        "\u2264": "<=",
        "\u2265": ">=",
        "\u2192": "->",
        "\u2713": "Y",
        "\u2714": "Y",
        "\u00a0": " ",
        "\u2019": "'",
    }
    for k, v in replacements.items():
        text = text.replace(k, v)
    # Fallback: replace any remaining non-latin-1 chars
    text = text.encode("latin-1", errors="replace").decode("latin-1")
    return text


def parse_markdown(filepath):
    """Parse the markdown into structured sections."""
    with open(filepath, "r") as f:
        content = f.read()
    return content


def render_table(pdf, lines):
    """Render a markdown table."""
    rows = []
    for line in lines:
        line = line.strip()
        if line.startswith("|"):
            cells = [c.strip() for c in line.split("|")[1:-1]]
            # Skip separator rows
            if all(set(c) <= set("-: ") for c in cells):
                continue
            rows.append(cells)

    if not rows:
        return

    header = rows[0]
    data = rows[1:]
    num_cols = len(header)

    # Calculate column widths based on content
    page_width = 180  # usable width
    col_widths = []
    for i in range(num_cols):
        max_len = len(header[i])
        for row in data:
            if i < len(row):
                max_len = max(max_len, len(row[i]))
        col_widths.append(max_len)

    total = sum(col_widths)
    col_widths = [max(w / total * page_width, 15) for w in col_widths]

    # Header
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_fill_color(240, 240, 240)
    for i, h in enumerate(header):
        w = col_widths[i] if i < len(col_widths) else 25
        pdf.cell(w, 6, safe(h), border=1, fill=True)
    pdf.ln()

    # Data rows
    pdf.set_font("Helvetica", "", 8)
    for row in data:
        # Calculate row height needed
        max_lines = 1
        cell_texts = []
        for i in range(num_cols):
            text = safe(row[i]) if i < len(row) else ""
            # Remove markdown bold
            text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
            cell_texts.append(text)
            w = col_widths[i] if i < len(col_widths) else 25
            lines_needed = max(1, int(pdf.get_string_width(text) / (w - 2)) + 1)
            max_lines = max(max_lines, lines_needed)

        row_h = max_lines * 5

        # Check page break
        if pdf.get_y() + row_h > 275:
            pdf.add_page()

        y_start = pdf.get_y()
        x_start = pdf.get_x()

        for i, text in enumerate(cell_texts):
            w = col_widths[i] if i < len(col_widths) else 25
            pdf.set_xy(x_start + sum(col_widths[:i]), y_start)
            pdf.multi_cell(w, 5, text, border=1)

        pdf.set_y(y_start + row_h)
        pdf.set_x(15)


def render_code_block(pdf, lines):
    """Render a code block with monospace font and background."""
    pdf.set_fill_color(245, 245, 245)
    pdf.set_font("Courier", "", 7.5)

    for line in lines:
        text = safe(line)
        if pdf.get_y() > 275:
            pdf.add_page()
        pdf.set_x(15)
        pdf.cell(180, 4.5, text, fill=True)
        pdf.ln()

    pdf.ln(2)


def render_text_line(pdf, text, indent=0):
    """Render a single text line with inline bold/code support."""
    text = safe(text)
    x = 15 + indent
    pdf.set_x(x)
    width = 180 - indent

    # Split by bold markers and code markers
    parts = re.split(r'(\*\*.*?\*\*|`[^`]+`)', text)

    # If simple enough, use multi_cell
    has_formatting = any(p.startswith("**") or p.startswith("`") for p in parts if p)

    if not has_formatting:
        pdf.set_font("Helvetica", "", 9.5)
        pdf.multi_cell(width, 5, text)
        return

    # For formatted text, render part by part
    line_parts = []
    for part in parts:
        if not part:
            continue
        if part.startswith("**") and part.endswith("**"):
            line_parts.append(("B", part[2:-2]))
        elif part.startswith("`") and part.endswith("`"):
            line_parts.append(("C", part[1:-1]))
        else:
            line_parts.append(("N", part))

    # Simple approach: concatenate and use multi_cell with bold approximation
    full_text = ""
    for kind, content in line_parts:
        full_text += content

    # Check if it fits in one line
    pdf.set_font("Helvetica", "", 9.5)
    if pdf.get_string_width(full_text) < width:
        # Render inline
        for kind, content in line_parts:
            if kind == "B":
                pdf.set_font("Helvetica", "B", 9.5)
            elif kind == "C":
                pdf.set_font("Courier", "", 8.5)
            else:
                pdf.set_font("Helvetica", "", 9.5)
            pdf.cell(pdf.get_string_width(content), 5, content)
        pdf.ln()
    else:
        # Multi-line: just use regular font
        pdf.set_font("Helvetica", "", 9.5)
        pdf.multi_cell(width, 5, full_text)


def main():
    md_path = "/Users/annli/.claude/plans/eventual-booping-sutton.md"

    with open(md_path, "r") as f:
        lines = f.readlines()

    pdf = PRDPdf()
    pdf.set_auto_page_break(auto=True, margin=20)
    pdf.add_page()

    # Title
    pdf.set_font("Helvetica", "B", 18)
    pdf.cell(0, 12, "AI Photographer", ln=True, align="C")
    pdf.set_font("Helvetica", "", 12)
    pdf.cell(0, 8, "PRD + Implementation Plan", ln=True, align="C")
    pdf.ln(8)

    i = 1  # Skip first line (title)
    in_code = False
    code_lines = []
    in_table = False
    table_lines = []

    while i < len(lines):
        line = lines[i].rstrip("\n")
        i += 1

        # Code block toggle
        if line.strip().startswith("```"):
            if in_code:
                # End code block
                render_code_block(pdf, code_lines)
                code_lines = []
                in_code = False
            else:
                # Flush any pending table
                if in_table and table_lines:
                    render_table(pdf, table_lines)
                    table_lines = []
                    in_table = False
                in_code = True
            continue

        if in_code:
            code_lines.append(line)
            continue

        # Table detection
        if line.strip().startswith("|"):
            if not in_table:
                in_table = True
                table_lines = []
            table_lines.append(line)
            continue
        elif in_table:
            render_table(pdf, table_lines)
            table_lines = []
            in_table = False

        # Empty line
        if not line.strip():
            pdf.ln(2)
            continue

        # Horizontal rule
        if line.strip() in ("---", "---\n"):
            pdf.ln(2)
            pdf.set_draw_color(200, 200, 200)
            pdf.line(15, pdf.get_y(), 195, pdf.get_y())
            pdf.ln(4)
            continue

        # H1
        if line.startswith("# "):
            text = safe(line[2:].strip())
            if pdf.get_y() > 250:
                pdf.add_page()
            pdf.ln(4)
            pdf.set_font("Helvetica", "B", 16)
            pdf.set_x(15)
            pdf.multi_cell(180, 7, text)
            pdf.ln(2)
            continue

        # H2
        if line.startswith("## "):
            text = safe(line[3:].strip())
            if pdf.get_y() > 260:
                pdf.add_page()
            pdf.ln(3)
            pdf.set_font("Helvetica", "B", 13)
            pdf.set_x(15)
            pdf.multi_cell(180, 6, text)
            pdf.ln(1)
            continue

        # H3
        if line.startswith("### "):
            text = safe(line[4:].strip())
            if pdf.get_y() > 265:
                pdf.add_page()
            pdf.ln(2)
            pdf.set_font("Helvetica", "B", 11)
            pdf.set_x(15)
            # Remove quotes from h3
            text = text.strip('"')
            pdf.multi_cell(180, 5.5, text)
            pdf.ln(1)
            continue

        # Bullet point
        if line.strip().startswith("- "):
            content = line.strip()[2:]
            # Check indent level
            indent = len(line) - len(line.lstrip())
            bullet_indent = min(indent, 8)

            if pdf.get_y() > 275:
                pdf.add_page()

            pdf.set_font("Helvetica", "", 9.5)
            pdf.set_x(15 + bullet_indent)
            pdf.cell(4, 5, "-")
            render_text_line(pdf, content, indent=bullet_indent + 5)
            continue

        # Numbered list
        m = re.match(r'^(\d+)\.\s+(.*)', line.strip())
        if m:
            num = m.group(1)
            content = m.group(2)
            if pdf.get_y() > 275:
                pdf.add_page()
            pdf.set_font("Helvetica", "B", 9.5)
            pdf.set_x(15)
            pdf.cell(8, 5, f"{num}.")
            render_text_line(pdf, content, indent=8)
            continue

        # Bold paragraph header (like **Step 1 -- ...**)
        if line.strip().startswith("**"):
            if pdf.get_y() > 270:
                pdf.add_page()
            pdf.ln(1)
            render_text_line(pdf, line.strip())
            continue

        # Regular text
        if pdf.get_y() > 275:
            pdf.add_page()
        render_text_line(pdf, line.strip())

    # Flush remaining
    if in_table and table_lines:
        render_table(pdf, table_lines)
    if in_code and code_lines:
        render_code_block(pdf, code_lines)

    output_path = "/Users/annli/Documents/AI photographer/AI_Photographer_PRD.pdf"
    pdf.output(output_path)
    print(f"PDF saved to: {output_path}")


if __name__ == "__main__":
    main()
