package retrieve

import (
	"embed"
	"fmt"
	"log"
	"net/http"
	"strings"
	"text/template"
)

//go:embed templates
var templates embed.FS

func clientOs(r *http.Request) string {
	if strings.Contains(r.UserAgent(), "PowerShell") {
		return "windows"
	} else {
		return "linux"
	}
}

// Read a file and write it to the response writer followed by a new line and surrounded by comments
func includeFile(rw http.ResponseWriter, name string) {
	if fr, err := templates.ReadFile(name); err != nil {
		log.Printf("error reading file %s: %s", name, err)
	} else {
		fmt.Fprintf(rw, "\n# BEGINNING of %s %s|\n\n", name, strings.Repeat("-", 102-len(name)))
		if _, err := rw.Write(fr); err != nil {
			log.Println("error writing http response: ", err)
		}
		fmt.Fprintf(rw, "\n# END of %s %s|\n\n", name, strings.Repeat("-", 108-len(name)))
	}
}

// Read a file and write it to the response writer followed by a new line
func includeFileRaw(rw http.ResponseWriter, name string) {
	if fr, err := templates.ReadFile(name); err != nil {
		log.Printf("error reading file %s: %s", name, err)
	} else {
		if _, err := rw.Write(fr); err != nil {
			log.Println("error writing http response: ", err)
		}
		fmt.Fprintln(rw)
	}
}

// Render a template and write it to the response writer
func renderTemplate(rw http.ResponseWriter, tplFile string, data interface{}) {
	fmt.Fprintf(rw, "## BEGINNING of rendered templarte %s \n", tplFile)
	tpl, err := template.ParseFS(templates, tplFile)
	if err != nil {
		fmt.Fprintf(rw, "# parsing template file %s failed:%s", tplFile, err)
		log.Printf("parsing template file %s failed:%s", tplFile, err)
		return
	}
	if err := tpl.Execute(rw, data); err != nil {
		fmt.Fprintf(rw, "# executing template file '%s' failed: %s", tplFile, err)
		log.Printf("executing template file '%s' failed: %s", tplFile, err)
	}
	fmt.Fprintf(rw, "\n## END of rendered template %s \n\n", tplFile)
}
