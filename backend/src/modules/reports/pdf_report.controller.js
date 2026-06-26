'use strict';

const PDFDocument = require('pdfkit');
const { query } = require('../../db/pool');

async function generateProjectPDF(req, res, next) {
  try {
    const projectId = req.params.id;

    // Fetch all project data in parallel
    const [projectRes, teamRes, reportsRes, snagRes] = await Promise.all([
      query(
        `SELECT p.*,
            u.full_name as supervisor_name
         FROM projects p
         LEFT JOIN users u ON u.id = p.supervisor_id
         WHERE p.id = $1`,
        [projectId]
      ),
      query(
        `SELECT u.full_name, u.role
         FROM project_assignments pa
         JOIN users u ON u.id = pa.user_id
         WHERE pa.project_id = $1 AND pa.active = true
         ORDER BY u.role, u.full_name`,
        [projectId]
      ),
      query(
        `SELECT work_done, created_at, type
         FROM daily_reports
         WHERE project_id = $1
         ORDER BY created_at DESC
         LIMIT 5`,
        [projectId]
      ),
      query(
        `SELECT
           COUNT(*) FILTER (WHERE status='open')::int as open_count,
           COUNT(*) FILTER (WHERE status='resolved')::int as resolved_count,
           COUNT(*) FILTER (WHERE status='closed')::int as closed_count
         FROM snag_items WHERE project_id = $1`,
        [projectId]
      ),
    ]);

    if (projectRes.rows.length === 0) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Project not found' } });
    }

    const project = projectRes.rows[0];
    const team = teamRes.rows;
    const reports = reportsRes.rows;
    const snag = snagRes.rows[0] || {};

    // Create PDF
    const doc = new PDFDocument({ margin: 50, size: 'A4' });

    const safeName = (project.project_name || 'project').replace(/[^a-zA-Z0-9_-]/g, '-');
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition',
      `attachment; filename="report-${safeName}-${Date.now()}.pdf"`);

    doc.pipe(res);

    const teal = '#00D1DC';
    const dark = '#1A1A2E';
    const grey = '#666666';

    // ── HEADER ──────────────────────────────────────────────
    doc.rect(0, 0, doc.page.width, 80).fill(teal);
    doc.fill('white').fontSize(22).font('Helvetica-Bold')
       .text('Metal & More Interiors', 50, 20);
    doc.fontSize(11).font('Helvetica')
       .text('Interior Design & Execution', 50, 48);
    doc.text(`Report generated: ${new Date().toLocaleDateString('en-IN', {
      day:'2-digit', month:'long', year:'numeric', hour:'2-digit', minute:'2-digit'
    })}`, 50, 62);

    doc.moveDown(3);

    // ── PROJECT INFO ─────────────────────────────────────────
    doc.fill(dark).fontSize(16).font('Helvetica-Bold')
       .text('Project Details', 50, 100);
    doc.moveTo(50, 120).lineTo(545, 120).stroke(teal);

    const info = [
      ['Project Name', project.project_name || '—'],
      ['Customer', project.customer_name || '—'],
      ['Current Stage', (project.current_stage || '').replace(/_/g, ' ').toUpperCase()],
      ['Supervisor', project.supervisor_name || 'Not assigned'],
    ];

    let y = 130;
    info.forEach(([label, value]) => {
      doc.fill(grey).fontSize(10).font('Helvetica').text(label, 50, y);
      doc.fill(dark).fontSize(10).font('Helvetica-Bold').text(value, 200, y);
      y += 20;
    });

    y += 10;

    // ── TEAM ─────────────────────────────────────────────────
    doc.fill(dark).fontSize(14).font('Helvetica-Bold').text('Project Team', 50, y);
    doc.moveTo(50, y + 18).lineTo(545, y + 18).stroke(teal);
    y += 28;

    if (team.length === 0) {
      doc.fill(grey).fontSize(10).text('No team members assigned', 50, y);
      y += 20;
    } else {
      team.forEach(member => {
        doc.fill(dark).fontSize(10).font('Helvetica')
           .text(`• ${member.full_name} (${member.role})`, 50, y);
        y += 16;
      });
    }

    y += 10;

    // ── SNAG SUMMARY ──────────────────────────────────────────
    doc.fill(dark).fontSize(14).font('Helvetica-Bold').text('Snag List Summary', 50, y);
    doc.moveTo(50, y + 18).lineTo(545, y + 18).stroke(teal);
    y += 28;

    [
      ['Open Issues', String(snag.open_count || 0)],
      ['Resolved', String(snag.resolved_count || 0)],
      ['Closed', String(snag.closed_count || 0)],
    ].forEach(([label, value]) => {
      doc.fill(grey).fontSize(10).font('Helvetica').text(label, 50, y);
      doc.fill(dark).fontSize(10).font('Helvetica-Bold').text(value, 200, y);
      y += 20;
    });

    y += 10;

    // ── RECENT REPORTS ────────────────────────────────────────
    if (reports.length > 0) {
      doc.fill(dark).fontSize(14).font('Helvetica-Bold').text('Recent Reports', 50, y);
      doc.moveTo(50, y + 18).lineTo(545, y + 18).stroke(teal);
      y += 28;

      reports.forEach((r, idx) => {
        const date = new Date(r.created_at).toLocaleDateString('en-IN');
        const text = `${idx + 1}. [${date}] ${(r.work_done || '').substring(0, 80)}${(r.work_done || '').length > 80 ? '...' : ''}`;
        doc.fill(dark).fontSize(9).font('Helvetica').text(text, 50, y, { width: 495 });
        y += 16;
      });
    }

    // ── FOOTER ────────────────────────────────────────────────
    doc.rect(0, doc.page.height - 40, doc.page.width, 40).fill(teal);
    doc.fill('white').fontSize(9).font('Helvetica')
       .text('Metal & More Interiors — Confidential — Generated by ICMS',
        50, doc.page.height - 26, { align: 'center' });

    doc.end();

  } catch (err) { next(err); }
}

module.exports = { generateProjectPDF };
