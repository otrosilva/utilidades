package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/gdamore/tcell/v2"
	"github.com/rivo/tview"
)

var (
	filePath = mustExpand("~/Documentos/Filen/Obsidian/bits.md")
	editor   = "micro"
)

type Entry struct {
	Fecha        string
	Tipo         string
	EventoRaw    string
	EventoNorm   string
	Comentario   string
	Transcurrido string
}

func mustExpand(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			panic(err)
		}
		return filepath.Join(home, path[2:])
	}
	return path
}

func normalizeEvento(s string) string {
	re := regexp.MustCompile(`[^a-zA-Z0-9áéíóúüñÁÉÍÓÚÜÑ\s\.\,\!\?\;\:\-]`)
	s = re.ReplaceAllString(s, "")
	accents := map[rune]rune{
		'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
		'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ü': 'u', 'Ñ': 'n',
	}
	var builder strings.Builder
	for _, r := range s {
		if repl, ok := accents[r]; ok {
			builder.WriteRune(repl)
		} else {
			builder.WriteRune(r)
		}
	}
	result := strings.ToLower(builder.String())
	space := regexp.MustCompile(`\s+`)
	result = space.ReplaceAllString(result, " ")
	return strings.TrimSpace(result)
}

func nowTimestamp() string {
	return time.Now().Format("2006-01-02 15:04")
}

func parseTimestamp(ts string) (time.Time, error) {
	return time.Parse("2006-01-02 15:04", ts)
}

func formatDiff(seconds int64) string {
	if seconds < 0 {
		return "?"
	}
	totalMin := seconds / 60
	if totalMin == 0 {
		return "0m"
	}
	days := totalMin / 1440
	hours := (totalMin % 1440) / 60
	mins := totalMin % 60
	parts := []string{}
	if days > 0 {
		parts = append(parts, fmt.Sprintf("%dd", days))
	}
	if hours > 0 {
		parts = append(parts, fmt.Sprintf("%dh", hours))
	}
	if mins > 0 {
		parts = append(parts, fmt.Sprintf("%dm", mins))
	}
	if len(parts) == 0 {
		return "0m"
	}
	return strings.Join(parts, "")
}

func repairLine(line string) string {
	line = strings.TrimSpace(line)
	if !strings.HasPrefix(line, "|") {
		line = "| " + line + " |"
	}
	fields := strings.Split(line, "|")
	var cleaned []string
	for _, f := range fields {
		f = strings.TrimSpace(f)
		if f != "" {
			cleaned = append(cleaned, f)
		}
	}
	for len(cleaned) < 5 {
		cleaned = append(cleaned, "")
	}
	if cleaned[0] == "fecha" || cleaned[0] == "" || !regexp.MustCompile(`^\d{4}-\d{2}-\d{2}`).MatchString(cleaned[0]) {
		cleaned[0] = nowTimestamp()
	}
	if cleaned[1] == "" || cleaned[2] == "" {
		return ""
	}
	if cleaned[3] == "" {
		cleaned[3] = "sin comentario"
	}
	return fmt.Sprintf("| %s | %s | %s | %s | %s |",
		cleaned[0], cleaned[1], cleaned[2], cleaned[3], cleaned[4])
}

func parseLine(line string) *Entry {
	line = strings.TrimSpace(line)
	if line == "" {
		return nil
	}
	if !strings.HasPrefix(line, "|") || strings.Count(line, "|") < 4 {
		line = repairLine(line)
		if line == "" {
			return nil
		}
	}
	fields := strings.Split(line, "|")
	if len(fields) < 7 {
		line = repairLine(line)
		if line == "" {
			return nil
		}
		fields = strings.Split(line, "|")
		if len(fields) < 7 {
			return nil
		}
	}
	fecha := strings.TrimSpace(fields[1])
	tipo := strings.TrimSpace(fields[2])
	eventoRaw := strings.TrimSpace(fields[3])
	comentario := strings.TrimSpace(fields[4])
	transcurrido := strings.TrimSpace(fields[5])

	if fecha == "fecha" || !regexp.MustCompile(`^\d{4}-\d{2}-\d{2}`).MatchString(fecha) {
		return nil
	}
	if tipo == "" || eventoRaw == "" {
		return nil
	}
	// Rechazar líneas corruptas con literales
	if tipo == "fecha" || eventoRaw == "tipo" {
		return nil
	}
	return &Entry{
		Fecha:        fecha,
		Tipo:         tipo,
		EventoRaw:    eventoRaw,
		EventoNorm:   normalizeEvento(eventoRaw),
		Comentario:   comentario,
		Transcurrido: transcurrido,
	}
}

func cleanFile() error {
	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	lines := strings.Split(string(data), "\n")
	var validLines []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "|") && strings.Count(line, "|") >= 4 {
			parts := strings.Split(line, "|")
			if len(parts) >= 2 {
				fechaCell := strings.TrimSpace(parts[1])
				if fechaCell == "fecha" || !regexp.MustCompile(`^\d{4}-\d{2}-\d{2}`).MatchString(fechaCell) {
					continue
				}
				if len(parts) >= 4 {
					tipoCell := strings.TrimSpace(parts[2])
					eventoCell := strings.TrimSpace(parts[3])
					if tipoCell == "fecha" || eventoCell == "tipo" {
						continue
					}
				}
			}
			validLines = append(validLines, line)
		}
	}
	var newContent strings.Builder
	newContent.WriteString("# Registro\n\n")
	newContent.WriteString("| Fecha | Tipo | Evento | Comentario | Transcurrido |\n")
	newContent.WriteString("| --- | --- | --- | --- | --- |\n")
	for _, line := range validLines {
		newContent.WriteString(line + "\n")
	}
	return os.WriteFile(filePath, []byte(newContent.String()), 0644)
}

func readEntries() ([]*Entry, error) {
	if err := cleanFile(); err != nil {
		return nil, err
	}
	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return []*Entry{}, nil
		}
		return nil, err
	}
	lines := strings.Split(string(data), "\n")
	var entries []*Entry
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") || strings.Contains(line, "---") {
			continue
		}
		if e := parseLine(line); e != nil {
			entries = append(entries, e)
		}
	}
	recalcTranscurrido(entries)
	return entries, nil
}

func recalcTranscurrido(entries []*Entry) {
	groups := make(map[string][]*Entry)
	for _, e := range entries {
		groups[e.EventoNorm] = append(groups[e.EventoNorm], e)
	}
	for _, group := range groups {
		sort.Slice(group, func(i, j int) bool {
			t1, _ := parseTimestamp(group[i].Fecha)
			t2, _ := parseTimestamp(group[j].Fecha)
			return t1.Before(t2)
		})
		var prevTime time.Time
		for i, e := range group {
			current, err := parseTimestamp(e.Fecha)
			if err != nil {
				continue
			}
			if i == 0 {
				e.Transcurrido = "inicio"
			} else {
				diff := current.Sub(prevTime)
				e.Transcurrido = formatDiff(int64(diff.Seconds()))
			}
			prevTime = current
		}
	}
}

func writeEntries(entries []*Entry) error {
	sort.Slice(entries, func(i, j int) bool {
		t1, _ := parseTimestamp(entries[i].Fecha)
		t2, _ := parseTimestamp(entries[j].Fecha)
		return t1.Before(t2)
	})
	recalcTranscurrido(entries)
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	f, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer f.Close()
	_, _ = f.WriteString("# Registro\n\n")
	_, _ = f.WriteString("| Fecha | Tipo | Evento | Comentario | Transcurrido |\n")
	_, _ = f.WriteString("| --- | --- | --- | --- | --- |\n")
	for _, e := range entries {
		_, _ = fmt.Fprintf(f, "| %s | %s | %s | %s | %s |\n",
			e.Fecha, e.Tipo, e.EventoRaw, e.Comentario, e.Transcurrido)
	}
	return nil
}

// ===== FUNCIONES DE NEGOCIO =====
func getOrCreateCategory(entries []*Entry, eventoNorm, eventoRaw string) string {
	for _, e := range entries {
		if e.EventoNorm == eventoNorm {
			return e.Tipo
		}
	}
	fmt.Print("Categoría para '" + eventoRaw + "' (escribe '?' para ver existentes): ")
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		input := strings.TrimSpace(scanner.Text())
		if input == "?" {
			cats := make(map[string]bool)
			for _, e := range entries {
				cats[e.Tipo] = true
			}
			var list []string
			for c := range cats {
				list = append(list, c)
			}
			sort.Strings(list)
			fmt.Println("Categorías existentes:")
			for _, c := range list {
				fmt.Println("  -", c)
			}
			fmt.Print("Categoría para '" + eventoRaw + "': ")
			continue
		}
		if input != "" {
			return input
		}
	}
	return "Evento"
}

func addEntry(entries *[]*Entry, eventoRaw, comentario string) (*Entry, error) {
	eventoNorm := normalizeEvento(eventoRaw)
	var last *Entry
	for i := len(*entries) - 1; i >= 0; i-- {
		if (*entries)[i].EventoNorm == eventoNorm {
			last = (*entries)[i]
			break
		}
	}
	tipo := ""
	if last != nil {
		tipo = last.Tipo
	} else {
		tipo = getOrCreateCategory(*entries, eventoNorm, eventoRaw)
	}
	transcurrido := "inicio"
	if last != nil {
		t1, _ := parseTimestamp(last.Fecha)
		t2, _ := parseTimestamp(nowTimestamp())
		diff := t2.Sub(t1)
		transcurrido = formatDiff(int64(diff.Seconds()))
	}
	newEntry := &Entry{
		Fecha:        nowTimestamp(),
		Tipo:         tipo,
		EventoRaw:    eventoRaw,
		EventoNorm:   eventoNorm,
		Comentario:   comentario,
		Transcurrido: transcurrido,
	}
	*entries = append(*entries, newEntry)
	return newEntry, writeEntries(*entries)
}

func deleteLastEntry(entries *[]*Entry, eventoNorm string) error {
	for i := len(*entries) - 1; i >= 0; i-- {
		if (*entries)[i].EventoNorm == eventoNorm {
			*entries = append((*entries)[:i], (*entries)[i+1:]...)
			return writeEntries(*entries)
		}
	}
	return fmt.Errorf("no hay entradas para el evento")
}

func deleteAllEntries(entries *[]*Entry, eventoNorm string) error {
	var newEntries []*Entry
	for _, e := range *entries {
		if e.EventoNorm != eventoNorm {
			newEntries = append(newEntries, e)
		}
	}
	*entries = newEntries
	return writeEntries(*entries)
}

func editEventEntries(entries *[]*Entry, eventoRaw, eventoNorm string) error {
	var eventEntries []*Entry
	for _, e := range *entries {
		if e.EventoNorm == eventoNorm {
			eventEntries = append(eventEntries, e)
		}
	}
	if len(eventEntries) == 0 {
		return fmt.Errorf("no hay entradas para el evento")
	}
	tmp, err := os.CreateTemp("", "bit_edit_*.md")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	_, _ = tmp.WriteString("# Editando: " + eventoRaw + "\n")
	_, _ = tmp.WriteString("# Formato: | fecha | tipo | evento | comentario | transcurrido |\n\n")
	for _, e := range eventEntries {
		_, _ = fmt.Fprintf(tmp, "| %s | %s | %s | %s | %s |\n",
			e.Fecha, e.Tipo, e.EventoRaw, e.Comentario, e.Transcurrido)
	}
	tmp.Close()
	cmd := exec.Command(editor, tmpName)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return err
	}
	newData, err := os.ReadFile(tmpName)
	if err != nil {
		return err
	}
	var parsed []*Entry
	for _, line := range strings.Split(string(newData), "\n") {
		e := parseLine(line)
		if e != nil {
			parsed = append(parsed, e)
		}
	}
	if len(parsed) == 0 {
		return fmt.Errorf("no se encontraron entradas válidas después de editar")
	}
	var result []*Entry
	replaced := false
	for _, e := range *entries {
		if e.EventoNorm != eventoNorm {
			result = append(result, e)
		} else if !replaced {
			result = append(result, parsed...)
			replaced = true
		}
	}
	if !replaced {
		result = append(result, parsed...)
	}
	*entries = result
	return writeEntries(*entries)
}

func renameEvent(entries *[]*Entry, oldNorm, oldRaw, newRaw string) error {
	newNorm := normalizeEvento(newRaw)
	for i, e := range *entries {
		if e.EventoNorm == oldNorm {
			(*entries)[i].EventoRaw = newRaw
			(*entries)[i].EventoNorm = newNorm
		}
	}
	return writeEntries(*entries)
}

// ===== CLI =====
func mostrarAyuda() {
	fmt.Println(`Uso: bit [opciones] [evento] [comentario]

Opciones:
  -h, --help          Muestra esta ayuda.
  -l, --list          Lista todas las bitácoras agrupadas por categoría.
  -F, --fix           Limpia el archivo eliminando líneas corruptas.
  <evento>            Muestra todas las entradas del evento especificado.
  <evento> <comentario>   Añade una nueva entrada al evento (atajo rápido).
  -e, --edit <evento>   Edita todas las entradas del evento.
  -a, --add <evento> <comentario>   Añade una entrada (igual que el atajo).
  -d, --delete <evento>   Borra la última entrada del evento.
  -D, --delete-all <evento>  Borra TODAS las entradas del evento (pide confirmación).

Ejemplos:
  bit                          # Muestra resumen por categorías
  bit gato                     # Muestra todas las entradas de "gato"
  bit gato "duerme en la silla"  # Añade una entrada rápida
  bit -a gato "duerme"         # Mismo que arriba
  bit -e gato                  # Edita las entradas de "gato"
  bit -d gato                  # Borra la última entrada de "gato"
  bit -D gato                  # Borra todas las entradas de "gato"
  bit -F                       # Limpia el archivo`)
}

func listar(entries []*Entry) {
	if len(entries) == 0 {
		fmt.Println("No hay entradas")
		return
	}
	byCategory := make(map[string]map[string]int)
	for _, e := range entries {
		if byCategory[e.Tipo] == nil {
			byCategory[e.Tipo] = make(map[string]int)
		}
		byCategory[e.Tipo][e.EventoRaw]++
	}
	cats := make([]string, 0, len(byCategory))
	for c := range byCategory {
		cats = append(cats, c)
	}
	sort.Strings(cats)
	for _, cat := range cats {
		fmt.Println()
		fmt.Printf("| %s | #   |\n", cat)
		fmt.Println("| --- | --- |")
		events := make([]string, 0, len(byCategory[cat]))
		for ev := range byCategory[cat] {
			events = append(events, ev)
		}
		sort.Strings(events)
		for _, ev := range events {
			fmt.Printf("| %s | %d |\n", ev, byCategory[cat][ev])
		}
	}
}

func mostrarEvento(entries []*Entry, evento string) {
	norm := normalizeEvento(evento)
	var found []*Entry
	for _, e := range entries {
		if e.EventoNorm == norm {
			found = append(found, e)
		}
	}
	if len(found) == 0 {
		fmt.Printf("No hay entradas para el evento '%s'\n", evento)
		return
	}
	fmt.Println("| Fecha | Tipo | Evento | Comentario | Transcurrido |")
	fmt.Println("| --- | --- | --- | --- | --- |")
	for _, e := range found {
		comentario := strings.ReplaceAll(e.Comentario, "|", "\\|")
		fmt.Printf("| %s | %s | %s | %s | %s |\n",
			e.Fecha, e.Tipo, e.EventoRaw, comentario, e.Transcurrido)
	}
}

func eventosConPrefijo(entries []*Entry, prefijo string) []string {
	prefNorm := normalizeEvento(prefijo)
	seen := make(map[string]bool)
	var result []string
	for _, e := range entries {
		if strings.HasPrefix(e.EventoNorm, prefNorm) {
			if !seen[e.EventoNorm] {
				seen[e.EventoNorm] = true
				result = append(result, e.EventoRaw)
			}
		}
	}
	sort.Strings(result)
	return result
}

func runCLI() {
	entries, err := readEntries()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error leyendo archivo: %v\n", err)
		os.Exit(1)
	}
	args := os.Args[1:]
	if len(args) == 0 {
		listar(entries)
		return
	}
	expand := func(arg string) string {
		switch arg {
		case "--help": return "-h"
		case "--list": return "-l"
		case "--edit": return "-e"
		case "--add": return "-a"
		case "--delete": return "-d"
		case "--delete-all": return "-D"
		case "--fix": return "-F"
		default: return arg
		}
	}
	first := expand(args[0])
	switch first {
	case "-h":
		mostrarAyuda()
	case "-l":
		listar(entries)
	case "-F":
		if err := cleanFile(); err != nil {
			fmt.Fprintf(os.Stderr, "Error al limpiar: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Archivo limpiado correctamente.")
		return
	case "-e":
		if len(args) < 2 {
			fmt.Println("Error: falta el nombre del evento")
			mostrarAyuda()
			os.Exit(1)
		}
		evento := args[1]
		norm := normalizeEvento(evento)
		matching := eventosConPrefijo(entries, evento)
		if len(matching) == 0 {
			fmt.Printf("No existe ninguna bitácora que empiece por '%s'\n", evento)
			os.Exit(1)
		}
		if len(matching) > 1 {
			fmt.Printf("Bitácoras que coinciden con '%s':\n", evento)
			for _, ev := range matching {
				fmt.Printf("  - %s\n", ev)
			}
			os.Exit(1)
		}
		if err := editEventEntries(&entries, matching[0], norm); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Editado: %s\n", matching[0])
	case "-a":
		if len(args) < 3 {
			fmt.Println("Error: uso: bit -a <evento> <comentario>")
			os.Exit(1)
		}
		evento := args[1]
		comentario := strings.Join(args[2:], " ")
		if _, err := addEntry(&entries, evento, comentario); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("+ %s | %s | %s | inicio\n", nowTimestamp(), evento, evento)
	case "-d":
		if len(args) < 2 {
			fmt.Println("Error: falta el nombre del evento")
			os.Exit(1)
		}
		evento := args[1]
		matching := eventosConPrefijo(entries, evento)
		if len(matching) == 0 {
			fmt.Printf("No existe ninguna bitácora que empiece por '%s'\n", evento)
			os.Exit(1)
		}
		if len(matching) > 1 {
			fmt.Printf("Bitácoras que coinciden con '%s':\n", evento)
			for _, ev := range matching {
				fmt.Printf("  - %s\n", ev)
			}
			os.Exit(1)
		}
		norm := normalizeEvento(matching[0])
		if err := deleteLastEntry(&entries, norm); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("- %s | %s\n", nowTimestamp(), matching[0])
	case "-D":
		if len(args) < 2 {
			fmt.Println("Error: falta el nombre del evento")
			os.Exit(1)
		}
		evento := args[1]
		matching := eventosConPrefijo(entries, evento)
		if len(matching) == 0 {
			fmt.Printf("No existe ninguna bitácora que empiece por '%s'\n", evento)
			os.Exit(1)
		}
		if len(matching) > 1 {
			fmt.Printf("Bitácoras que coinciden con '%s':\n", evento)
			for _, ev := range matching {
				fmt.Printf("  - %s\n", ev)
			}
			os.Exit(1)
		}
		fmt.Printf("¿Borrar TODAS las entradas de '%s'? (s/n): ", matching[0])
		var resp string
		fmt.Scanln(&resp)
		if resp != "s" && resp != "S" {
			fmt.Println("Cancelado")
			return
		}
		norm := normalizeEvento(matching[0])
		if err := deleteAllEntries(&entries, norm); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Borradas todas las entradas de '%s'\n", matching[0])
	default:
		evento := args[0]
		if len(args) == 1 {
			matching := eventosConPrefijo(entries, evento)
			if len(matching) == 0 {
				fmt.Printf("No existe ninguna bitácora que empiece por '%s'\n", evento)
				os.Exit(1)
			}
			if len(matching) > 1 {
				fmt.Printf("Bitácoras que coinciden con '%s':\n", evento)
				for _, ev := range matching {
					fmt.Printf("  - %s\n", ev)
				}
				os.Exit(1)
			}
			mostrarEvento(entries, matching[0])
		} else {
			comentario := strings.Join(args[1:], " ")
			if _, err := addEntry(&entries, evento, comentario); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("+ %s | %s | %s | inicio\n", nowTimestamp(), evento, evento)
		}
	}
}

// ===== TUI =====
type App struct {
	app      *tview.Application
	pages    *tview.Pages
	events   *tview.TreeView
	table    *tview.Table
	status   *tview.TextView
	entries  []*Entry
	currentEventNorm string
	allNodes []*tview.TreeNode
}

func (a *App) refreshEventsTree() {
	root := tview.NewTreeNode("📁 Bitácoras").SetColor(tcell.ColorYellow)
	cats := make(map[string][]*Entry)
	for _, e := range a.entries {
		cats[e.Tipo] = append(cats[e.Tipo], e)
	}
	var sortedCats []string
	for c := range cats {
		sortedCats = append(sortedCats, c)
	}
	sort.Strings(sortedCats)
	for _, cat := range sortedCats {
		catNode := tview.NewTreeNode(cat).SetColor(tcell.ColorGreen)
		eventMap := make(map[string]string)
		for _, e := range cats[cat] {
			eventMap[e.EventoNorm] = e.EventoRaw
		}
		var norms []string
		for norm := range eventMap {
			norms = append(norms, norm)
		}
		sort.Strings(norms)
		for _, norm := range norms {
			raw := eventMap[norm]
			node := tview.NewTreeNode(raw).SetReference(norm).SetColor(tcell.ColorWhite)
			catNode.AddChild(node)
		}
		root.AddChild(catNode)
	}
	a.events.SetRoot(root).SetCurrentNode(root)
	a.updateNodeList()
}

func (a *App) updateNodeList() {
	a.allNodes = nil
	var traverse func(node *tview.TreeNode)
	traverse = func(node *tview.TreeNode) {
		a.allNodes = append(a.allNodes, node)
		for _, child := range node.GetChildren() {
			traverse(child)
		}
	}
	traverse(a.events.GetRoot())
}

func (a *App) moveSelection(delta int) {
	if len(a.allNodes) == 0 {
		return
	}
	current := a.events.GetCurrentNode()
	idx := -1
	for i, n := range a.allNodes {
		if n == current {
			idx = i
			break
		}
	}
	if idx == -1 {
		return
	}
	newIdx := idx + delta
	if newIdx < 0 {
		newIdx = 0
	}
	if newIdx >= len(a.allNodes) {
		newIdx = len(a.allNodes) - 1
	}
	if newIdx != idx {
		a.events.SetCurrentNode(a.allNodes[newIdx])
		if ref := a.allNodes[newIdx].GetReference(); ref != nil {
			if norm, ok := ref.(string); ok {
				a.showEntries(norm)
				a.updateStatus("Mostrando: " + a.allNodes[newIdx].GetText())
			}
		}
	}
}

func (a *App) showEntries(eventoNorm string) {
	a.currentEventNorm = eventoNorm
	var entries []*Entry
	for _, e := range a.entries {
		if e.EventoNorm == eventoNorm {
			entries = append(entries, e)
		}
	}
	sort.Slice(entries, func(i, j int) bool {
		t1, _ := parseTimestamp(entries[i].Fecha)
		t2, _ := parseTimestamp(entries[j].Fecha)
		return t1.After(t2)
	})
	a.table.Clear()
	a.table.SetCell(0, 0, tview.NewTableCell("Fecha").SetTextColor(tcell.ColorYellow))
	a.table.SetCell(0, 1, tview.NewTableCell("Comentario").SetTextColor(tcell.ColorYellow))
	a.table.SetCell(0, 2, tview.NewTableCell("Transcurrido").SetTextColor(tcell.ColorYellow))
	for i, e := range entries {
		a.table.SetCell(i+1, 0, tview.NewTableCell(e.Fecha))
		a.table.SetCell(i+1, 1, tview.NewTableCell(e.Comentario))
		a.table.SetCell(i+1, 2, tview.NewTableCell(e.Transcurrido))
	}
	a.table.ScrollToBeginning()
}

func (a *App) updateStatus(msg string) {
	a.status.SetText(msg)
}

func (a *App) showCommentModal(eventoRaw string, callback func(string)) {
	form := tview.NewForm()
	inputField := tview.NewInputField()
	inputField.SetLabel("Comentario: ").SetFieldWidth(60)
	form.AddFormItem(inputField)
	form.AddButton("Aceptar", func() {
		text := inputField.GetText()
		a.pages.SwitchToPage("main")
		callback(text)
	})
	form.AddButton("Cancelar", func() {
		a.pages.SwitchToPage("main")
		callback("")
	})
	flex := tview.NewFlex().SetDirection(tview.FlexRow).AddItem(form, 0, 1, true)
	a.pages.AddPage("commentModal", flex, true, false)
	a.pages.SwitchToPage("commentModal")
	a.app.SetFocus(form)
}

func (a *App) showRenameModal(oldRaw string, callback func(string)) {
	form := tview.NewForm()
	inputField := tview.NewInputField()
	inputField.SetLabel("Nuevo nombre: ").SetFieldWidth(40)
	form.AddFormItem(inputField)
	form.AddButton("Aceptar", func() {
		newRaw := inputField.GetText()
		a.pages.SwitchToPage("main")
		callback(newRaw)
	})
	form.AddButton("Cancelar", func() {
		a.pages.SwitchToPage("main")
		callback("")
	})
	flex := tview.NewFlex().SetDirection(tview.FlexRow).AddItem(form, 0, 1, true)
	a.pages.AddPage("renameModal", flex, true, false)
	a.pages.SwitchToPage("renameModal")
	a.app.SetFocus(form)
}

func (a *App) confirmDeleteAll(eventoRaw string, callback func(bool)) {
	modal := tview.NewModal().
		SetText("¿Borrar TODAS las entradas de '" + eventoRaw + "'?").
		AddButtons([]string{"Sí", "No"}).
		SetDoneFunc(func(buttonIndex int, buttonLabel string) {
			a.pages.SwitchToPage("main")
			callback(buttonIndex == 0)
		})
	a.pages.AddPage("confirm", modal, true, false)
	a.pages.SwitchToPage("confirm")
}

func (a *App) showHelp() {
    helpText := `Atajos:
  j/k : Navegar hacia abajo/arriba
  a : Añadir entrada al evento seleccionado
  e : Editar evento seleccionado
  r : Renombrar evento (todas sus entradas)
  d : Borrar la última entrada
  D : Borrar TODAS las entradas
  q : Salir
  ? : Esta ayuda`
    modal := tview.NewModal().SetText(helpText).AddButtons([]string{"OK"}).SetDoneFunc(func(buttonIndex int, buttonLabel string) {
        a.pages.SwitchToPage("main")
    })
    a.pages.AddPage("help", modal, true, false)
    a.pages.SwitchToPage("help")
}

func (a *App) editCurrentEvent() {
	node := a.events.GetCurrentNode()
	if node == nil {
		a.updateStatus("No hay nodo seleccionado")
		return
	}
	ref := node.GetReference()
	if ref == nil {
		a.updateStatus("No es un evento (es una categoría)")
		return
	}
	norm, ok := ref.(string)
	if !ok {
		return
	}
	eventoRaw := node.GetText()
	err := editEventEntries(&a.entries, eventoRaw, norm)
	if err != nil {
		a.updateStatus("Error: " + err.Error())
	} else {
		newEntries, err := readEntries()
		if err == nil {
			a.entries = newEntries
		}
		a.refreshEventsTree()
		a.showEntries(norm)
		a.updateStatus("Evento editado")
	}
}

func (a *App) renameCurrentEvent() {
	node := a.events.GetCurrentNode()
	if node == nil {
		a.updateStatus("No hay nodo seleccionado")
		return
	}
	ref := node.GetReference()
	if ref == nil {
		a.updateStatus("No es un evento (es una categoría)")
		return
	}
	oldNorm, ok := ref.(string)
	if !ok {
		return
	}
	oldRaw := node.GetText()
	a.showRenameModal(oldRaw, func(newRaw string) {
		if newRaw == "" || newRaw == oldRaw {
			a.updateStatus("Renombrado cancelado")
			return
		}
		err := renameEvent(&a.entries, oldNorm, oldRaw, newRaw)
		if err != nil {
			a.updateStatus("Error al renombrar: " + err.Error())
			return
		}
		newEntries, err := readEntries()
		if err == nil {
			a.entries = newEntries
		}
		a.refreshEventsTree()
		newNorm := normalizeEvento(newRaw)
		a.showEntries(newNorm)
		a.updateStatus("Evento renombrado a: " + newRaw)
	})
}

func (a *App) run() {
	a.app = tview.NewApplication()
	a.pages = tview.NewPages()
	a.events = tview.NewTreeView()
	a.table = tview.NewTable().SetSelectable(true, false)
	a.status = tview.NewTextView().SetTextAlign(tview.AlignCenter)

	a.events.SetSelectedFunc(func(node *tview.TreeNode) {
		if ref := node.GetReference(); ref != nil {
			if norm, ok := ref.(string); ok {
				a.showEntries(norm)
				a.updateStatus("Mostrando: " + node.GetText())
			}
		}
	})

	a.app.SetInputCapture(func(event *tcell.EventKey) *tcell.EventKey {
	    current, _ := a.pages.GetFrontPage()
	    if current != "main" {
	        return event
	    }
	    switch event.Key() {
	    case tcell.KeyRune:
	        switch event.Rune() {
	        case 'j':
	            a.moveSelection(1)
	            return nil
	        case 'k':
	            a.moveSelection(-1)
	            return nil
	        case 'a':
	            node := a.events.GetCurrentNode()
	            if node == nil || node.GetReference() == nil {
	                a.updateStatus("Selecciona un evento primero")
	                return nil
	            }
	            eventoRaw := node.GetText()
	            a.showCommentModal(eventoRaw, func(comentario string) {
	                if comentario != "" {
	                    _, err := addEntry(&a.entries, eventoRaw, comentario)
	                    if err != nil {
	                        a.updateStatus("Error: " + err.Error())
	                    } else {
	                        a.refreshEventsTree()
	                        a.showEntries(normalizeEvento(eventoRaw))
	                        a.updateStatus("Entrada añadida")
	                    }
	                } else {
	                    a.updateStatus("Cancelado")
	                }
	            })
	            return nil
	        case 'e':
	            a.editCurrentEvent()
	            return nil
	        case 'r':
	            a.renameCurrentEvent()
	            return nil
	        case 'd':
	            node := a.events.GetCurrentNode()
	            if node == nil || node.GetReference() == nil {
	                a.updateStatus("Selecciona un evento")
	                return nil
	            }
	            eventoNorm := node.GetReference().(string)
	            err := deleteLastEntry(&a.entries, eventoNorm)
	            if err != nil {
	                a.updateStatus("Error: " + err.Error())
	            } else {
	                a.refreshEventsTree()
	                a.showEntries(eventoNorm)
	                a.updateStatus("Última entrada borrada")
	            }
	            return nil
	        case 'D':
	            node := a.events.GetCurrentNode()
	            if node == nil || node.GetReference() == nil {
	                a.updateStatus("Selecciona un evento")
	                return nil
	            }
	            eventoRaw := node.GetText()
	            eventoNorm := node.GetReference().(string)
	            a.confirmDeleteAll(eventoRaw, func(confirmed bool) {
	                if confirmed {
	                    err := deleteAllEntries(&a.entries, eventoNorm)
	                    if err != nil {
	                        a.updateStatus("Error: " + err.Error())
	                    } else {
	                        a.refreshEventsTree()
	                        a.table.Clear()
	                        a.currentEventNorm = ""
	                        a.updateStatus("Borradas todas las entradas")
	                    }
	                } else {
	                    a.updateStatus("Cancelado")
	                }
	            })
	            return nil
	        case '?':
	            a.showHelp()
	            return nil
	        case 'q':
	            a.app.Stop()
	            return nil
	        }
	    }
	    // Se ha eliminado el case para tcell.KeyEnter
	    return event
	})

	flex := tview.NewFlex().SetDirection(tview.FlexColumn)
	flex.AddItem(a.events, 0, 1, true)
	flex.AddItem(a.table, 0, 2, false)
	main := tview.NewFlex().SetDirection(tview.FlexRow)
	main.AddItem(flex, 0, 1, true)
	main.AddItem(a.status, 1, 0, false)

	a.pages.AddPage("main", main, true, true)
	a.app.SetRoot(a.pages, true)

	entries, err := readEntries()
	if err != nil {
		panic(err)
	}
	a.entries = entries
	a.refreshEventsTree()
	a.showEntries("")

	if err := a.app.Run(); err != nil {
		panic(err)
	}
}

func main() {
	if len(os.Args) > 1 {
		runCLI()
	} else {
		app := &App{}
		app.run()
	}
}
