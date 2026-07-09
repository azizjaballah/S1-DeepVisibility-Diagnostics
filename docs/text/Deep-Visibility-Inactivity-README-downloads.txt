Deep Visibility Inactivity – README 
(für S1-DeepVisibility-PassiveDiag.ps1)
1. Zweck dieses Skripts
Das PowerShell-Skript S1-DeepVisibility-PassiveDiag.ps1 dient dazu, herauszufinden, warum bestimmte Endpunkte keine Deep-Visibility-(DV)-Daten an SentinelOne senden, obwohl der Agent in der Managementkonsole sichtbar ist.
Das Skript:
	•	ist rein passiv, macht also keine Konfigurationsänderungen
	•	konzentriert sich auf den lokalen Agentstatus und die Netzwerkverbindung zum Deep-Visibility-Gateway
	•	erzeugt einen JSON-Bericht, der gefundene Probleme zusammenfasst
Es ist für die Endpunkte gedacht, die wir Ihnen mit dieser Mail schicken.

2. Voraussetzungen
	•	Windows-Endpunkt mit installiertem SentinelOne-Agent
	•	PowerShell (Version 5 oder höher, standardmäßig auf unterstützten Windows-Versionen)
	•	Lokale Administratorrechte (PowerShell „Als Administrator ausführen“)
	•	Kenntnis des Deep-Visibility-Gateway-Hosts Ihres SentinelOne-Tenants  (z.B. ioc-gw-prod-eu-1b.sentinelone.net) 
Im Folgenden wird der Deep-Visibility-Gateway-Host $VisibilityHost genannt!
3. Bereitgestellte Dateien
Sie haben bereits Folgendes erhalten:
	•	Eine Liste der betroffenen Endpunkte (z. B. als CSV oder Excel)
	•	PowerShell-Skript: S1-DeepVisibility-PassiveDiag.ps1
	•	Dieses README, das Ihnen als Anleitung zum Starten des Skripts und Troubleshooten dienen soll

4. Ausführen des Skripts
	•	Kopieren Sie S1-DeepVisibility-PassiveDiag.ps1 auf den Endpunkt.
	•	Öffnen Sie PowerShell als Administrator.
	•	Navigieren Sie zum Ordner mit dem Skript, indem Sie beispielsweise folgenden Befehl ausführen: cd C:\Users\USERNAME\Downloads 
	•	Skriptausführung für diese Sitzung erlauben: Set-ExecutionPolicy Bypass -Scope Process -Force 
	•	Skript starten, inkl. Angabe des DV-Gateway-Hosts:
.\S1-DeepVisibility-PassiveDiag.ps1 -S1VisibilityHost "$VisibilityHost" -VerboseOutput 
	•	Das Skript erzeugt die Ausgabe unter:  C:\Windows\Temp\S1-DeepVisibilityDiag.json
In dieser JSON finden Sie die Ergebnisse des Skripts, die zur Behebung des Problems notwendig sind.
5. Was das Skript prüft
Das Skript prüft mehrere Dinge:
5.1. Konnektivität zu wichtigen URLs/IPs
Das Skript prüft die Konnektivität zu diesen URLs/IPs:
	•	https://dv-eu-prod.sentinelone.net
	•	https://ioc-gw-eu.sentinelone.net
	•	https://ioc-gw-eu-1a.sentinelone.net
	•	https://ioc-gw-eu-1b.sentinelone.net
	•	https://ioc-gw-eu-1c.sentinelone.net
	•	18.195.202.253
	•	18.195.205.47
	•	18.196.241.73
	•	34.224.32.67
5.2. Agent- und Systemstatus
	•	Existenz und Status des SentinelAgent Dienstes
	•	Agent-Version und Installationspfad
	•	Laufende Kernprozesse:
	•	SentinelAgent
	•	SentinelAgentWorker
	•	SentinelStaticEngine
	•	Basis-Betriebssysteminformationen:
	•	OS-Version und Build
	•	Letzte Boot-Zeit
	•	Zeitzone
5.3. Deep-Visibility-Konfiguration
Aus der Registry:  HKLM:\SOFTWARE\SentinelOne\Sentinel Agent
Es werden geprüft:
	•	DeepVisibilityEnabled
	•	DeepVisibilityMode
	•	NetworkQuarantineEnabled
	•	Weitere Metadaten wie AgentId, SiteId, ManagementUrl (falls vorhanden)
5.4. Netzwerk- und TLS-Konnektivität
Für den angegebenen Visibility-Host (-S1VisibilityHost):
	•	DNS-Auflösung (Resolve-DnsName)
	•	TCP Port 443 (Test-NetConnection)
	•	TLS-1.2-Test (Invoke-WebRequest mit erzwungenem TLS 1.2)
Das Skript unterscheidet:
	•	normale HTTP-Antworten (2xx–4xx)
	•	HTTP 407 Proxy Authentication Required
	•	sonstige TLS/HTTP-Fehler
Hinweis: DV-Gateways können nicht-Agent-Requests absichtlich ablehnen. Das Skript wertet diese nur dann als Fehler, wenn sie Proxy-Probleme anzeigen.
5.5. Proxy- und Firewall-Kontext
	•	WinHTTP-Proxy
	•	IE/System-Proxy im Benutzerkontext
	•	Umgebungsvariablen: HTTP_PROXY, HTTPS_PROXY
	•	Windows Firewall Status und SentinelOne-bezogene Regeln
5.6. Agent-Logs und aktive Netzwerkverbindungen
	•	Prüft Log-Ordner:
	•	C:\ProgramData\SentinelOne\Logs\Agent\SentinelAgent.log
	•	C:\Program Files\SentinelOne\Sentinel Agent\Logs\SentinelAgent.log
	•	Sammelt:
	•	Loggröße + letztes Änderungsdatum
	•	bis zu 10 aktuelle Zeilen mit ERROR / WARN / FAIL / „Deep Visibility“
	•	Identifiziert aktive TCP-Verbindungen, besonders:
	•	Domains mit „sentinelone“
	•	Remote Port 443
6. Interpretation der Ergebnisse
Das JSON enthält ein Feld DetectedIssues, eine Liste verständlicher Meldungen mit drei Stufen:
	•	CRITICAL – Funktionalität beeinträchtigt
	•	WARNING – mögliche Beeinträchtigungen
	•	INFO – Hinweise, nicht unbedingt Probleme
Exit-Codes:
	•	0 – keine kritischen/warnenden Probleme
	•	1 – mindestens ein CRITICAL
	•	2 – keine kritischen, aber mindestens ein WARNING
7. Häufige Befunde und empfohlene Maßnahmen
7.1. Agent service not running (CRITICAL)
Beispielantwort:
	•	CRITICAL: SentinelAgent service is Stopped 
	•	CRITICAL: SentinelAgent service not found
Was das bedeutet:
	•	Der SentinelOne Windows Service läuft nicht oder fehlt.
	•	Deep Visibility funktioniert nicht auf diesem Endpunkt.
Was Sie machen können:
	•	Überprüfen Sie die Windows-Ereignisprotokolle (Application und System) auf dienstbezogene Fehler.
	•	Prüfen Sie, ob der SentinelOne-Agent korrekt installiert ist.
	•	Versuchen Sie, den Dienst neu zu starten: Restart-Service SentinelAgent
	•	Wenn der Dienst wiederholt nicht startet, sollte Ihre interne IT oder SentinelOne/QGroup-Support eingebunden werden.
7.2. DNS-resolution failed (CRITICAL)
Beispielantwort:  CRITICAL: Cannot resolve ioc-gw-prod-eu-1b.sentinelone.net
Was das bedeutet:  Der Endpunkt kann den DV-Gateway-Hostnamen nicht per DNS auflösen.
Was Sie machen können:
	•	DNS-Serverkonfiguration des Endpunkts prüfen.
	•	Sicherstellen, dass es keine internen DNS-Overrides oder blockierten Zonen für *.sentinelone.net gibt.
	•	Testen, ob der Endpunkt andere externe Hosts auflösen kann (z. B. www.microsoft.com).

7.3. TCP-Port 443 blocked (CRITICAL)
Beispielantwort:  CRITICAL: Cannot reach ioc-gw-prod-eu-1b.sentinelone.net on port 443
Was das bedeutet:  Der Endpunkt kann keine ausgehende HTTPS-Verbindung zum DV-Gateway herstellen.
Was Sie machen können:
	•	Windows-Firewallregeln auf dem Endpunkt prüfen.
	•	Unternehmens-Firewall/Proxy-Regeln prüfen, ob ausgehendes HTTPS zum DV-Gateway erlaubt ist.
	•	Sicherstellen, dass keine Sicherheitslösung (NAC, NIPS usw.) den Traffic blockiert oder verwirft.

7.4. Proxy authentication required – HTTP 407 (CRITICAL)
Beispielantwort:  CRITICAL: HTTP 407 Proxy Authentication Required for https://… – proxy prevents Deep Visibility connectivity.
Was das bedeutet:  Ein Proxy fängt den Traffic zum DV-Gateway ab und verlangt Authentifizierung, die der Agent nicht liefern kann.
Was Sie machen können:
	•	Mit dem Netzwerk-/Proxy-Team klären:
	•	Ausnahme für SentinelOne-DV-Traffic definieren
	•	dem Agent Proxy-Zugang ermöglichen, falls technisch möglich
	•	Sicherstellen, dass der DV-Gateway-Host sowie erforderliche SentinelOne-Domains ungehindert durchgelassen werden.

7.5. Agent processes not running (WARNING)
Beispielantwort:  WARNING: SentinelAgent process not running
Was das bedeutet:  Ein oder mehrere notwendige Agent-Prozesse laufen nicht.
Was Sie machen können:
	•	Ereignisprotokolle sowie Agent-Logs auf Fehler prüfen.
	•	SentinelAgent-Dienst neu starten.
	•	Wenn das Problem bleibt: Neuinstallation oder Upgrade des Agents in Betracht ziehen.

7.6. Network quarantine enabled (WARNING)
Beispielantwort:  WARNING: Agent is in network quarantine mode
Was das bedeutet:  Der Endpunkt befindet sich in einer durch Richtlinie aktivierten Netzwerkquarantäne, wodurch DV blockiert sein kann.
Was Sie machen können:
	•	Endpoint-Status und angewendete Policy in der SentinelOne-Konsole prüfen.
	•	Falls Quarantäne nicht beabsichtigt ist, Policy anpassen und Endpoint wieder freigeben.

7.7. TLS test failed (INFO)
Beispielantwort:  INFO: TLS 1.2 test failed – this may be normal for Deep Visibility endpoints that reject non agent requests.
Was das bedeutet:  Der synthetische TLS-Test scheiterte, was bei DV-Endpunkten normal sein kann, da diese Nicht-Agent-Anfragen ablehnen.
Was Sie machen können:
	•	Dies als rein informativ betrachten, sofern DNS und Port 443 funktionieren.
	•	Den Fokus auf DNS, Port 443, Proxy und Agent-Gesundheit legen.

7.8. DV configuration missing in registry (INFO)
Beispielantwort:  INFO: Deep Visibility configuration not in registry (may be managed only by console)
Was das bedeutet:  Die DV-Konfiguration ist lokal nicht in der Registry vorhanden. Je nach Architektur kann dies normal sein.
Was Sie machen können:
	•	Prüfen, ob Deep Visibility in der SentinelOne-Konsole für Site oder Group aktiviert ist.
	•	Ergebnisse mit einem funktionierenden Endpunkt vergleichen, der DV-Daten sendet.

8. Wann eskalieren?
Wenn nach:
	•	Durchführung des Skripts
	•	Prüfung aller CRITICAL/WARNING-Funde
	•	Kontrolle von Firewalls, Proxies, DNS, Agent-Status
keine Ursache gefunden oder behoben werden kann,
dann kontaktieren SIe bitte QGroup SecOps und übermitteln:
	•	S1-DeepVisibilityDiag.json von betroffenen Endpunkten
	•	kurze Beschreibung der Netzwerk-/Proxy-Umgebung
	•	relevante Beobachtungen

