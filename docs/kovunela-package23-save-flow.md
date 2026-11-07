# Paket 23 – Katalogverarbeitung beim Speichern

Der Nutzer prüft den KI-Vorschlag und drückt „Speichern“. Das ist die einzige Bestätigung.

Der vollständige Datensatz verbleibt privat. Beim erfolgreichen Speichern soll automatisch ein Eintrag in der internen Katalogbeitragswarteschlange entstehen. Ein Hintergrundprozess prüft die allgemeinen Basisdaten auf erlaubte Felder, Quellenrechte, Duplikate und Qualität, bevor Informationen im zentralen Online-Katalog veröffentlicht werden.

Keine zusätzliche Bestätigungs-Schaltfläche. Die bisherige zusätzliche Bestätigungs-RPC aus dem Zwischenstand von Paket 23 ist durch einen automatischen Speichervorgang zu ersetzen.

Persönliche Daten, Fotos, Notizen und ungeprüfte Drittanbieter-Inhalte dürfen nicht öffentlich werden.

Status: Architekturkorrektur; die Korrektur der SQL-Migration und die Flutter-Integration müssen separat getestet werden.