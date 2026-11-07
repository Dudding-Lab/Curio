# Kovunela Web-App – dauerhafte Produktgrundlage

## Entscheidung
Die erste Web-Version ist **keine separate Test-App**. Es wird der vorhandene Flutter-Code aus `flutter_app/` weiterentwickelt. Login, Sammlungen, Haushalte, Objektverwaltung, KI-Erkennung und gemeinsamer Katalog wachsen im gleichen Codebestand.

## Bereits vorhanden
- Supabase Auth mit E-Mail/Passwort und geschützte Routen
- Responsive Startseite, Navigation, Benutzeroberfläche für persönliche Objekte, Sammlungen und Haushalte
- KI-/Foto-/ISBN-Vorschau, noch nicht vollständig speicherfähig
- Neue browsergerechte Login-Darstellung; Startseite zeigt angemeldete E-Mail und bietet Abmelden
- `.github/workflows/kovunela-web.yml` erstellt einen Flutter-Web-Build des **vorhandenen** Projekts und veröffentlicht ein downloadbares GitHub-Actions-Artefakt

## GitHub-Einstellungen für den Build
In Repository → Settings → Secrets and variables → Actions → **Variables**:
- `KOVUNELA_SUPABASE_URL` = URL des *aktuellen Entwicklungsprojekts* (kein altes Projekt)
- `KOVUNELA_SUPABASE_PUBLISHABLE_KEY` = dessen Publishable Key

Nur den clientseitig vorgesehenen Publishable Key verwenden; **niemals** `service_role`, Datenbankpasswörter oder geheime Schlüssel dort eintragen. Der Web-Build enthält diese öffentlichen Konfigurationswerte. Supabase-RLS und serverseitige RPC-Autorisierung sind deshalb zwingend.

GitHub Workflow → `Kovunela web build` → Run workflow. Das Ergebnis ist ein Build-Artefakt, **noch keine öffentlich erreichbare Website**. Eine echte HTTPS-Adresse und Hosting-/Deployment-Konfiguration (mit passenden Supabase Auth Redirect URLs) sind gesondert einzurichten. Web-Plattform-Dateien werden bis dahin im Workflow per `flutter create --platforms=web --project-name curio .` generiert.

## Sicherheits- und Funktionsgates
- Die manuelle Speicherfunktion ist derzeit durch `KOVUNELA_ENABLE_PERSONAL_ITEM_SAVE` standardmäßig deaktiviert. Erst nach echten Zwei-Benutzer-Berechtigungstests aktivieren.
- Die Foto-/KI-Übertragung ist durch `KOVUNELA_ENABLE_VISION_UPLOAD` standardmäßig deaktiviert. Erst nach Datenschutz-, JWT- und Abrechnungstests aktivieren.
- Browser-Offline-Verhalten ist gesondert zu prüfen; keine lokale Kopie des Gemeinschaftskatalogs.
- Erst Build/CI, danach HTTPS-Hosting und reale Logins mit den beiden bereits angelegten Testbenutzern.
- Keine Veröffentlichung von persönlichen Daten oder ungeklärten KI-/Drittanbieter-Fakten im gemeinsamen Katalog.

## Grenzen dieses Entwicklungsschritts
Der Code ist im Feature-Branch vorhanden. Ein erfolgreicher Web-Build und eine bereitgestellte HTTPS-Domain wurden noch nicht bestätigt. Die Web-Version darf nicht als fertig deployt beschrieben werden.


## Build-Prüfung ohne veröffentlichte Konfiguration
GitHub Actions führt auch ohne die beiden Repository-Variablen einen **reinen Kompilierungstest** aus. Dafür werden absichtlich nicht funktionsfähige Platzhalter verwendet. Nur wenn beide echten Werte hinterlegt sind, lädt der Workflow das Artefakt `kovunela-web` hoch. Ein Platzhalter-Build ist keine nutzbare Web-App und darf nicht deployt werden.

## Offene Einrichtung zur ersten HTTPS-Version
Die Werte `KOVUNELA_SUPABASE_URL` und `KOVUNELA_SUPABASE_PUBLISHABLE_KEY` müssen in GitHub Actions Variables hinterlegt werden. Anschließend benötigen wir ein HTTPS-Hostingziel und die richtige Supabase-Auth-Konfiguration. Die beiden Testkonten existieren bereits und haben bestätigte E-Mail-Adressen, aber es gibt noch keine gehostete Anmeldeseite.


## Wiederholbarer Zwei-Benutzer-Sicherheitstest
Workflow `.github/workflows/two-user-integration.yml` ist manuell auslösbar (`workflow_dispatch`). Er verwendet die beiden bestehenden Testbenutzer `test1@kovunela.com` und `test2@kovunela.com`.

Zusätzlich zu den beiden GitHub Actions Variables müssen unter **Settings → Secrets and variables → Actions → Secrets** ausschließlich für diese künstlichen Testkonten die Secrets `KOVUNELA_TEST_PASSWORD_A` und `KOVUNELA_TEST_PASSWORD_B` gesetzt werden. Keine Passwörter im Chat, im Repository oder in YAML ablegen.

Der Workflow führt den vorhandenen realen `two_user_supabase_integration_test.dart` mit zwei getrennten JWT-Sitzungen aus, erzeugt Testobjekte in Supabase Development und prüft fremde Zugriffsversuche. Er ist wegen dieser echten Schreiboperationen **absichtlich nicht** bei jedem Commit aktiv. Noch kein echter Zwei-Nutzer-Testlauf durchgeführt.

## CI-Nachweise
Flutter-Testlauf nach Reparatur des Startseiten-Widgettests: https://github.com/Dudding-Lab/Curio/actions/runs/42359732224
Flutter-Web-Kompilierung ohne deploybare Konfiguration: https://github.com/Dudding-Lab/Curio/actions/runs/42359735458
