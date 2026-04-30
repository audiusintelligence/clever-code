# Clever Company Brand Guide

Verbindlich für alle Solutions auf der Clever Company Plattform.

## Foundation: `@audiusintelligence/ui`

Alle Solutions nutzen das interne Design System. **Niemals** eigene Buttons, Inputs, Layouts bauen - immer aus dem Package importieren.

```bash
npm install @audiusintelligence/ui
```

```tsx
import { Button, Card, Input, AppLayout, Header, DataTable } from '@audiusintelligence/ui';
import '@audiusintelligence/ui/styles';
```

## Tailwind Setup

```js
// tailwind.config.js
import preset from '@audiusintelligence/ui/preset';

export default {
  presets: [preset],
  content: [
    './src/**/*.{ts,tsx}',
    './node_modules/@audiusintelligence/ui/dist/**/*.js',
  ],
};
```

## Farben

### Audius Brand Palette
- `audius-primary` - Primärfarbe für Aktionen, Links, Highlights
- `audius-blue` - Standard-Blau
- `audius-blue-light` / `audius-blue-hover` - States
- `audius-navy` - Dunkle Akzente, Headers
- `audius-steel` - Metallisches Grau
- `audius-amber` - Warnungen, Hervorhebungen
- `audius-crimson` - Errors, Destructive Actions

### Apple Gray Scale (Texte, Hintergründe, Borders)
- `apple-gray-50` bis `apple-gray-900` (Standard-Skala wie macOS)

### Semantische Farben
- `primary` - Hauptaktion
- `success` - Grün für Erfolg
- `warning` - Gelb/Amber
- `error` - Rot
- `info` - Blau

**Regel:** Nutze **immer** semantische Klassen (`bg-primary`, `text-error`), nie Hex-Codes oder rohe Farb-Klassen wie `bg-blue-500`.

## Typografie

```tsx
// Font Stacks
font-sans        // Standard UI Text (System-Sans)
font-montserrat  // Headlines, Branding
font-mono        // Code, IDs, Monospace
```

### Hierarchie

| Element | Klassen |
|---------|---------|
| H1 (Page Title) | `text-3xl font-bold font-montserrat tracking-tight` |
| H2 (Section) | `text-2xl font-semibold font-montserrat` |
| H3 (Card Title) | `text-lg font-medium` |
| Body | `text-base` (Default) |
| Caption | `text-sm text-apple-gray-600` |
| Label | `text-sm font-medium` |

## Spacing & Layout

- **Page Container:** `max-w-7xl mx-auto px-4 sm:px-6 lg:px-8`
- **Section Spacing:** `space-y-6` (zwischen Karten/Bereichen)
- **Card Padding:** Standard durch `<Card>` Component
- **Border Radius:** `rounded-lg` (Standard), `rounded-pill` (Buttons), `rounded-full` (Avatare)

## Komponenten-Standards

### Layout
```tsx
// Jede Solution-Page so:
<AppLayout
  header={<Header user={user} solution="My Solution" />}
  sidebar={<Sidebar items={navItems} />}
>
  <YourContent />
</AppLayout>
```

### Buttons
```tsx
<Button variant="primary">Speichern</Button>      // Hauptaktion
<Button variant="secondary">Abbrechen</Button>     // Sekundär
<Button variant="ghost">Mehr</Button>              // Tertiär
<Button variant="destructive">Löschen</Button>     // Destruktiv

<Button size="sm" />   // klein
<Button size="md" />   // default
<Button size="lg" />   // groß
```

### Forms
- Immer `<Input label="..." error={...} />` aus dem Package
- Validierung mit Zod-Schemas
- Error-Messages auf Deutsch (`required` → "Pflichtfeld")
- Submit-Buttons rechts, Cancel links

### Datentabellen
```tsx
<DataTable
  data={items}
  columns={[
    { key: 'name', label: 'Name', sortable: true },
    { key: 'createdAt', label: 'Erstellt', format: 'date' },
  ]}
  emptyState={<EmptyState message="Noch keine Einträge" />}
/>
```

### Toasts (Notifications)
```tsx
import { toast } from '@audiusintelligence/ui';
toast.success('Gespeichert');
toast.error('Fehler beim Speichern');
```

## Sprache

- **UI immer Deutsch** (außer Solution explizit international)
- **Code-Kommentare Englisch**
- **Datum:** `DD.MM.YYYY HH:mm` (deutsches Format)
- **Zahlen:** Tausender-Punkt, Komma-Dezimal (`1.234,56`)
- **Currency:** Symbol nach Zahl mit Leerzeichen (`1.234,56 €`)

## Icons

Lucide Icons (über `lucide-react`):
```tsx
import { Plus, Edit, Trash2, Search } from 'lucide-react';
```

Größen:
- `w-4 h-4` - inline mit Text
- `w-5 h-5` - Standard für Buttons
- `w-6 h-6` - Headers, Cards

## Accessibility

- **Alle interaktiven Elemente** brauchen `aria-label` oder sichtbaren Text
- **Kontrast:** mindestens WCAG AA (Tokens sind das schon)
- **Keyboard-Navigation:** Tab-Order muss logisch sein
- **Modal Focus Trap:** automatisch via `<Modal>` Component

## Dark Mode

Solutions unterstützen Dark Mode automatisch via `<ThemeProvider>`. **Niemals** eigene `dark:` Klassen schreiben - das System Token erledigt das.

```tsx
import { ThemeProvider } from '@audiusintelligence/ui';

<ThemeProvider defaultTheme="system">
  <App />
</ThemeProvider>
```

## Beispiel: Vollständige Page

```tsx
import { AppLayout, Header, Sidebar, Card, Button, DataTable } from '@audiusintelligence/ui';
import { Plus } from 'lucide-react';

export default function ItemsPage() {
  return (
    <AppLayout
      header={<Header user={user} solution="Invoice Tracker" />}
      sidebar={<Sidebar items={[{ label: 'Rechnungen', href: '/invoices' }]} />}
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        <div className="flex justify-between items-center">
          <h1 className="text-3xl font-bold font-montserrat">Rechnungen</h1>
          <Button variant="primary">
            <Plus className="w-5 h-5" />
            Neue Rechnung
          </Button>
        </div>

        <Card>
          <DataTable data={invoices} columns={columns} />
        </Card>
      </div>
    </AppLayout>
  );
}
```

## Referenzen

- **Storybook:** `packages/ui/storybook-static/` (alle Components live)
- **Gold Standards:** `clever-company/procurement` & `intelligence/insights`
- **Source:** https://github.com/audiusintelligence/audius-ki/tree/main/packages/ui
