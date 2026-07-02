---
name: report-api
description: "Start the report-generator FastAPI server at ~/projects/report-generator \u2014 multi-source data aggregation with PDF (WeasyPrint), Excel, HTML, and Plotly outputs, plus an MCP server. TRIGGER WHEN: 'start the report generator API', 'run the report-generator server', 'work on report-generator', 'generate a report via the API'. DO NOT USE WHEN: working on a different reporting or analytics tool."
---

# Report Api

Start the report generator API server at ~/projects/report-generator. This is a multi-source report generation system with FastAPI.

Steps:
1. Navigate to ~/projects/report-generator
2. Activate virtual environment: source venv/bin/activate
3. Start API server: uvicorn src.report_generator.api:app --reload
4. Confirm server started
5. Show API documentation URL: http://localhost:8000/docs

Key features:
- Multi-source data aggregation
- Report templates with Jinja2
- Output formats: PDF (WeasyPrint), Excel, HTML
- Data visualization with Plotly
- Pandas for data manipulation
- Scheduled report generation
- Email delivery of reports
- Custom branding and styling

Report types:
- Business analytics reports
- Financial summaries
- Sales dashboards
- Compliance reports
- Custom ad-hoc reports

The MCP server provides additional tools for:
- Template management
- Report scheduling
- Data source configuration
