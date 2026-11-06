# Kovunela – Offline-First als verbindliche Architektur

Stand: 06.11.2026 · Branch `feature/kovunela-ui-foundation` · Paket 19, Grundlage.

## Architekturentscheidung

**Lokale Datenhaltung ist primär, Cloud-Synchronisation sekundär.** Lokal erfolgreich gespeicherte Änderungen müssen auch ohne Internetverbindung nutzbar bleiben. Synchronisation kann später beim App-Start, nach Konnektivitätswechsel, beim Wiederaufwecken und ausdrücklich manuell angestoßen werden. Auf Android/iOS sind garantierte Hintergrundintervalle technisch nicht möglich.

### Phase 1: bereits im Entwicklungsbranch implementiert

- Exakt gepinnte Abhängigkeiten `drift 2.32.1`, `drift_flutter 0.3.0`, `uuid 4.5.2`.
- `OfflineDatabase` besitzt SQLite-Tabellen `offline_records` und `pending_mutations`. Datensatzarten: `item`, `collection`, `category`, `template`, `workspace`. Die aktuell strukturlose lokale `payload_json`-Darstellung ist absichtlich ein **Zwischenstand**; die volle relationale Abbildung von Gegenständen, Kategorien, Felddefinitionen, Anhängen und Beziehungen folgt separat.
- Jeder Datensatz ist über `account_id` und `workspace_id` eingegrenzt; gleicher Datensatzschlüssel in unterschiedlichen Konten oder Bereichen überschreibt nichts.
- `putRecord` sichert **Datensatz plus unverwechselbare Mutation in einer einzigen lokalen SQL-Transaktion**. `deleteRecord` speichert einen Tombstone statt ungesyncte Löschungen zu verlieren.
- Einträge der Outbox besitzen UUID als Idempotenzschlüssel, unveränderliches JSON-Payload, lokale Revisionsnummer, Zielobjekt und optional die zuletzt bekannte Serverversion.
- `pendingForAccount` gibt nur die Outbox eines Kontos zurück; `acknowledgeMutation` löscht eine Mutation ausschließlich mit dem passenden Kontobezeichner und nur nach **externer, nachweislicher** Bestätigung. Es gibt noch keinen automatischen Worker oder Server-Endpunkt, der eine solche Bestätigung erzeugt.
- Unit-Tests prüfen Transaktions-/Outbox-Grundlage, Mehrkontentrennung, Löschmarkierung, Revisionsfolge und Account-gebundene Bestätigung.

Die neuen Funktionen werden **noch nicht** als produktives Offline-Speichern in die bestehende App/Erfassungsansicht gehängt. Vorhandene Online-Repositories bleiben unverändert; damit werden die bisherigen Sicherheitsfreigaben nicht umgangen.

### Sicherheits- und Konsistenzvorgaben für Phase 2

1. **Berechtigungsgeprüfter Sync-Vertrag** in Supabase: kein generischer JSON-RPC für beliebige Tabellen/Workspaces. Serverseitige Operationen validieren `auth.uid()`, Rollen, Zuordnung und Felddefinitionen.
2. **Idempotenz:** langlebige serverseitige Tabelle für `mutation_id`, Account, Ergebnis und Zeitpunkt, mit eindeutiger Schlüsselbindung. Wiederholung eines Uploads führt nicht zu einem zweiten Gegenstand. Clients quittieren nur explizit bestätigte IDs.
3. **Optimistische Versionierung:** Gegenstände, Sammlungen und Vorlagen erhalten Serverversionsnummern; Konflikte erzeugen nachvollziehbare Ergebnisse statt stillem „letzter gewinnt“.
4. **Löschungen:** Tombstones mindestens bis zur bestätigten Synchronisierung behalten; keine unbemerkte Wiederbelebung durch alte Geräte.
5. **Pull-/Delta-Protokoll:** Cursor je Konto/Bereich, stabile Ordnung und nachvollziehbare Sichtbarkeitsänderungen. Haushaltseinladungen und Rollenanpassungen werden ausschließlich online bestätigt.
6. **Entzogener Haushaltszugriff:** lokaler Zugriff nach serverseitig erkanntem Entzug muss gesperrt, lokale Kopien bereinigt werden. Während vollständiger Offlinephasen kann keine Fernlöschung garantiert werden. Für geteilte Daten muss eine gesonderte Offline-Session-/Schlüsselrichtlinie festgelegt werden.
7. **At-rest-Verschlüsselung:** Die Phase-1-SQLite-Datenbank ist **noch nicht appseitig verschlüsselt**. Bevor reale Benutzerinhalte lokal persistiert werden, sind Schlüsselverwaltung via Android Keystore / iOS Keychain, verschlüsselte Datenbank und Umgang mit Backups und Logout zu implementieren und zu testen. Bloße Konto-Filter in SQL sind keine echte Schutzgrenze bei lokalem Dateizugriff.
8. **Datenintegrität:** Änderungen an Vorlagen und ihren Metadaten erfordern Versions-Snapshots. Medien und Bilddateien brauchen eigene lokale Datei-Indizes, Upload-Quittungen und Löschregeln.
9. **App-Lifecycle:** Sync nur unter zuverlässiger Auth; kein blindes Anstoßen nach Verbindungsanzeige. Wiederholungen mit Backoff, begrenzten Batches, Aussetzen bei Logout und Berücksichtigung von Betriebsystemrestriktionen.
10. **Test-Gate:** echte Zwei-Benutzer-/Zwei-Geräte-Tests (Offline-Erfassung, konkurrierende Updates, Rollenentzug, Konflikt, Doppelsendungen, Neuinstallation, App-Abbruch) vor der Aktivierung jeglicher schreibender Cloud-Synchronisation.

### Phase 3: UI-Umstellung

Nach Abschluss der Sync-API und verschlüsselter Speicherung werden Home, Listen, Vorlageneditor und CaptureReview von unmittelbaren Supabase-Aufrufen auf lokale, beobachtbare Drift-Repositories umgestellt. Sync-Status wird sichtbar als **lokal gespeichert / ausstehend / synchronisiert / Konflikt** dargestellt. Server-/KI-Funktionen, die online bleiben, werden als solche gekennzeichnet.

**Wichtig:** Offline-First bedeutet keine automatischen, kostenpflichtigen KI-Anfragen. Der separate Bildanalyse-Kill-Switch, die Zustimmungspflicht und die gesperrte Gegenstands-Speicherung bleiben erhalten.

## Qualitätssicherung

Der normale Flutter-CI-Workflow führt `flutter pub get`, `flutter gen-l10n`, `flutter analyze` und `flutter test` auf dem Entwicklungsbranch aus. Die SQL-Datenmodelle von Supabase wurden in Paket 19 bewusst **nicht** verändert. Das neue SQLite-Modell ist nicht bereits ein vollständiger synchronisierter Produktionsdatenbestand.
