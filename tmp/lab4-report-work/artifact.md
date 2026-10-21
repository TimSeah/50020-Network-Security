# Lab 4 report template contract

## Reference
- Retained reference: `C:\Users\user\Documents\GitHub\50020-Network-Security\Lab 3\submission\Lab3_1007654_Timothy_Seah.docx`
- SHA-256: d3b4bcd9f9c90cf66015b69185c0e4378ad2b641c94c3b165322d36c531b9b5e
- Page count verified from companion PDF: 7; one section, portrait A4.
- Render evidence: companion PDF pages 1-7 were rendered to `tmp/lab4-report-work/lab3-pdf-page-*.png` and inspected. Direct DOCX renderer could not find bundled LibreOffice (`soffice.exe`) in this environment.
- Style audit: `tmp/lab4-report-work/lab3-style.json`; section audit: one section, 8.27 x 11.69 in, margins L/R 0.68 in, T 0.66 in, B 0.69 in.

## Page and style system
- Paper: A4 portrait; one section; no header/footer content; no first-page variant.
- Body: Aptos 9.5 pt, color #17212B, 5 pt after, 1.12 line spacing.
- Title: Word Title style, 19 pt bold black, 10 pt after.
- Heading 1: 14 pt bold black, 13 pt before, 6 pt after, keep with next.
- Heading 2: 10.5 pt bold black, 9 pt before, 4 pt after, keep with next.
- Figure captions: custom `Lab Caption` style, 8 pt, #4E6270, 2 pt before, 7 pt after.
- Tables: existing Normal Table design with pale blue header, thin gray-blue grid, compact text. Use only for comparable items.
- Figures: centered screenshots at or below 6.7 in wide, caption immediately after; preserve relevant browser address/payload/result in each crop.

## Content flow and editable slots
1. Title: `Lab 4 Web Attacks`; metadata: course, author, student ID, date; one concise summary paragraph.
2. Section 1 setup: Kali local lab, portal and document share URLs, shell commands; one table summarizing components and one dashboard screenshot.
3. Section 2 SQL injection: login bypass, DB/table/column discovery, private ticket access, user account enumeration, admin password update; payloads shown as editable text and evidence figures inserted. Qualify that current username screenshot does not display hash values.
4. Section 3 XSS: reflected and stored demonstrations; include input payloads, observed result, brief prevention discussion; figures inserted.
5. Section 4 CSRF: Alice pending/direct denied, admin pending, published document opened under admin session, request approved; include the hidden-image HTML and concise finding; figures inserted.
6. Section 5 AI-assisted detection: an explicit pending placeholder for the user to complete later. Do not invent detector code/results or AI reflection.

## Package preservation and edit scope
- Keep the retained Lab 3 DOCX byte-for-byte unchanged.
- Preserve page setup, theme, styles, numbering definitions, and custom caption/table styles by building from a copied DOCX.
- Replace report body content and its figures/tables as intended; create all new body text and image relationships for Lab 4.
- No source citations or tool tokens inside the report. The report remains editable.

