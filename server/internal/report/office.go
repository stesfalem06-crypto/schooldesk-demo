package report

import (
	"archive/zip"
	"bytes"
	"fmt"
	"strings"
)

func DOCX(doc Document) ([]byte, error) {
	var body strings.Builder
	body.WriteString(paragraph(doc.School, true, 32))
	body.WriteString(paragraph(doc.Title, true, 24))
	if doc.Subtitle != "" {
		body.WriteString(paragraph(doc.Subtitle, false, 20))
	}
	var images [][]byte
	for _, sec := range doc.Sections {
		body.WriteString(paragraph(sec.Title, true, 26))
		for _, line := range sec.Lines {
			body.WriteString(paragraph(line, false, 20))
		}
		if sec.Table != nil {
			body.WriteString(wordTable(sec.Table))
		}
		if len(sec.Chart) > 0 {
			images = append(images, sec.Chart)
			n := len(images)
			body.WriteString(fmt.Sprintf(`<w:p><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="5400000" cy="2800000"/><wp:docPr id="%d" name="Chart%d"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="%d" name="chart.png"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rIdImg%d"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="5400000" cy="2800000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>`, n, n, n, n))
		}
	}
	document := `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
<w:body>` + body.String() + `
<w:sectPr><w:footerReference w:type="default" r:id="rIdFooter"/><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1000" w:right="1000" w:bottom="1000" w:left="1000"/></w:sectPr>
</w:body></w:document>`
	footer := `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:t>` + xml(Footer) + `</w:t></w:r></w:p></w:ftr>`
	rels := `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>`
	var docRels strings.Builder
	docRels.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer.xml"/>`)
	overrides := `<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/footer.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>`
	files := map[string]string{
		"[Content_Types].xml": "",
		"_rels/.rels":         rels,
		"word/document.xml":   document,
		"word/footer.xml":     footer,
	}
	bins := map[string][]byte{}
	for i, img := range images {
		name := fmt.Sprintf("word/media/chart%d.png", i+1)
		bins[name] = img
		docRels.WriteString(fmt.Sprintf(`<Relationship Id="rIdImg%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/chart%d.png"/>`, i+1, i+1))
		overrides += `<Default Extension="png" ContentType="image/png"/>`
	}
	docRels.WriteString(`</Relationships>`)
	files["word/_rels/document.xml.rels"] = docRels.String()
	files["[Content_Types].xml"] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>` + overrides + `</Types>`
	return zipText(files, bins)
}

func PPTX(doc Document) ([]byte, error) {
	slides := []Section{{Title: doc.School, Lines: []string{doc.Title, doc.Subtitle}}}
	slides = append(slides, doc.Sections...)
	var sldList, presRels, overrides strings.Builder
	files := map[string]string{}
	bins := map[string][]byte{}
	presRels.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`)
	for i, sec := range slides {
		n := i + 1
		rid := fmt.Sprintf("rId%d", n)
		sldList.WriteString(fmt.Sprintf(`<p:sldId id="%d" r:id="%s"/>`, 255+n, rid))
		presRels.WriteString(fmt.Sprintf(`<Relationship Id="%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide%d.xml"/>`, rid, n))
		overrides.WriteString(fmt.Sprintf(`<Override PartName="/ppt/slides/slide%d.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>`, n))
		body := slideText(sec, n)
		files[fmt.Sprintf("ppt/slides/slide%d.xml", n)] = body
		rels := `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`
		if len(sec.Chart) > 0 {
			bins[fmt.Sprintf("ppt/media/chart%d.png", n)] = sec.Chart
			rels += fmt.Sprintf(`<Relationship Id="rIdImg" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/chart%d.png"/>`, n)
		}
		rels += `</Relationships>`
		files[fmt.Sprintf("ppt/slides/_rels/slide%d.xml.rels", n)] = rels
	}
	presRels.WriteString(`</Relationships>`)
	files["ppt/presentation.xml"] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" saveSubsetFonts="1">
<p:sldIdLst>` + sldList.String() + `</p:sldIdLst>
<p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>
<p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>`
	files["ppt/_rels/presentation.xml.rels"] = presRels.String()
	files["_rels/.rels"] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>`
	files["[Content_Types].xml"] = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="png" ContentType="image/png"/>
<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>` + overrides.String() + `</Types>`
	return zipText(files, bins)
}

func slideText(sec Section, n int) string {
	var b strings.Builder
	b.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>`)
	b.WriteString(shape(2, 400000, 280000, 11000000, 700000, sec.Title, 2800, true))
	var lines []string
	lines = append(lines, sec.Lines...)
	if sec.Table != nil {
		if len(sec.Table.Headers) > 0 {
			lines = append(lines, strings.Join(sec.Table.Headers, " | "))
		}
		for _, row := range sec.Table.Rows {
			lines = append(lines, strings.Join(row, " | "))
		}
	}
	text := strings.Join(lines, "\n")
	b.WriteString(shape(3, 400000, 1100000, 11000000, 4700000, text, 1600, false))
	if len(sec.Chart) > 0 {
		b.WriteString(fmt.Sprintf(`<p:pic><p:nvPicPr><p:cNvPr id="4" name="chart"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="rIdImg"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="6200000" y="1400000"/><a:ext cx="5200000" cy="2800000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>`))
	}
	b.WriteString(shape(5, 400000, 6400000, 11400000, 320000, Footer, 1000, false))
	b.WriteString(`</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>`)
	_ = n
	return b.String()
}

func shape(id int, x, y, cx, cy int, text string, size int, bold bool) string {
	weight := "norm"
	if bold {
		weight = "b"
	}
	parts := strings.Split(text, "\n")
	var runs strings.Builder
	for i, line := range parts {
		if i > 0 {
			runs.WriteString(`<a:br/>`)
		}
		runs.WriteString(fmt.Sprintf(`<a:r><a:rPr lang="en-US" sz="%d" b="%s" dirty="0"/><a:t>%s</a:t></a:r>`, size, map[bool]string{true: "1", false: "0"}[bold], xml(line)))
		_ = weight
	}
	return fmt.Sprintf(`<p:sp><p:nvSpPr><p:cNvPr id="%d" name="T%d"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="%d"/><a:ext cx="%d" cy="%d"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p>%s</a:p></p:txBody></p:sp>`, id, id, x, y, cx, cy, runs.String())
}

func paragraph(text string, bold bool, size int) string {
	b := ""
	if bold {
		b = `<w:b/>`
	}
	return fmt.Sprintf(`<w:p><w:r><w:rPr>%s<w:sz w:val="%d"/></w:rPr><w:t xml:space="preserve">%s</w:t></w:r></w:p>`, b, size, xml(text))
}

func wordTable(t *Table) string {
	var b strings.Builder
	b.WriteString(`<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/><w:tblBorders>
<w:top w:val="single" w:sz="4"/><w:left w:val="single" w:sz="4"/><w:bottom w:val="single" w:sz="4"/><w:right w:val="single" w:sz="4"/><w:insideH w:val="single" w:sz="4"/><w:insideV w:val="single" w:sz="4"/>
</w:tblBorders></w:tblPr>`)
	writeRow := func(cells []string, header bool) {
		b.WriteString(`<w:tr>`)
		for _, c := range cells {
			shd := ""
			if header {
				shd = `<w:shd w:val="clear" w:color="auto" w:fill="0E7C66"/>`
			}
			color := ""
			if header {
				color = `<w:color w:val="FFFFFF"/>`
			}
			b.WriteString(`<w:tc><w:tcPr>` + shd + `</w:tcPr><w:p><w:r><w:rPr>` + color + `<w:sz w:val="18"/></w:rPr><w:t>` + xml(c) + `</w:t></w:r></w:p></w:tc>`)
		}
		b.WriteString(`</w:tr>`)
	}
	writeRow(t.Headers, true)
	for _, row := range t.Rows {
		cells := make([]string, len(t.Headers))
		for i := range cells {
			if i < len(row) {
				cells[i] = row[i]
			}
		}
		writeRow(cells, false)
	}
	b.WriteString(`</w:tbl>`)
	return b.String()
}

func xml(s string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;").Replace(s)
}

func zipText(files map[string]string, bins map[string][]byte) ([]byte, error) {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, content := range files {
		w, err := zw.Create(name)
		if err != nil {
			return nil, err
		}
		if _, err := w.Write([]byte(content)); err != nil {
			return nil, err
		}
	}
	for name, content := range bins {
		w, err := zw.Create(name)
		if err != nil {
			return nil, err
		}
		if _, err := w.Write(content); err != nil {
			return nil, err
		}
	}
	if err := zw.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
