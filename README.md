# Lab: sinta na prática o que é um IDS e um IPS

**Tempo:** 60–90 min · **Nível:** iniciante · **Ferramentas:** Docker, Suricata, nmap, curl
**Segurança:** a rede do lab é isolada (`internal: true`). Ataque **somente** os containers deste lab.

## A ideia em 1 minuto
- **IDS** (Intrusion *Detection* System) = câmera de segurança. **Vê e avisa**, mas o ataque passa.
- **IPS** (Intrusion *Prevention* System) = câmera ligada a uma porta. **Vê e bloqueia**.

Neste lab há 3 containers:

| Container | Papel |
|---|---|
| `vitima` | servidor web (nginx) |
| `ids` | Suricata, "colado" na vítima: vê tudo que ela recebe |
| `atacante` | máquina com `nmap` e `curl` para atacar |

## Preparação
```bash
docker compose up -d --build
```
Abra **3 terminais** na pasta do lab (um para cada papel).

---
## Parte 1 — IDS: ele vê, mas não impede (30 min)

**Terminal 1 (IDS)** – ligue o Suricata em modo detecção:
```bash
docker exec ids suricata -i eth0 -S /etc/suricata/lab-rules/lab.rules -l /var/log/suricata -D
```
Aguarde ~15 s (ele carrega as regras). Depois acompanhe os alertas:
```bash
docker exec ids tail -f /var/log/suricata/fast.log
```

**Terminal 2 (atacante)** – faça os ataques, um de cada vez, e olhe o Terminal 1:
```bash
# 1) Scan de portas
docker exec atacante nmap -sS -T4 vitima

# 2) SQL Injection simulada
docker exec atacante curl "http://vitima/?id=1%20OR%201=1"

# 3) Acesso a uma área "proibida"
docker exec atacante curl http://vitima/admin/
```

✅ **Você deve ver 3 alertas** (`port scan`, `SQLi`, `acesso a /admin`) **e as respostas do servidor chegaram normalmente.**

**Perguntas**
1. Os ataques foram bloqueados? Como você sabe?
2. O que o IDS fez, exatamente?
3. Qual o horário, IP de origem e IP de destino do alerta de SQLi?

**Bônus (Wireshark):** em `docker exec atacante curl ...` o pacote com `OR 1=1` aparece em texto puro no HTTP. Por isso a regra o encontra.

---
## Parte 2 — Escreva sua própria regra (20 min)

Abra `rules/lab.rules`. Cada regra tem: **ação** (`alert`) · **protocolo** (`http`) · **origem → destino** · **opções** entre `( )`.

Adicione no final do arquivo:
```
alert http any any -> any any (msg:"LAB meu teste"; flow:to_server; http.uri; content:"/segredo"; sid:1000010; rev:1;)
```
Reinicie o Suricata para carregar a regra:
```bash
docker exec ids stop-suricata
docker exec ids suricata -i eth0 -S /etc/suricata/lab-rules/lab.rules -l /var/log/suricata -D
```
Aguarde ~15 s e teste:
```bash
docker exec atacante curl http://vitima/segredo
```
**Desafios**
1. Crie uma regra que alerte quando alguém acessar `/login`. Teste com `curl`.
2. Mude o `content` da sua regra. O que acontece com o alerta antigo? Por quê?
3. Dá para o atacante escapar da sua regra? (dica: `content:"/admin"` vs. `/ADMIN`). O que `nocase;` faz?

---
## Parte 3 — Virando IPS: agora ele bloqueia (20 min)

Pare o IDS e ligue o modo **inline**. Todo pacote passa primeiro pelo Suricata, e as regras com `drop` descartam o ataque:

```bash
docker exec ids stop-suricata
docker exec ids iptables -I INPUT  -j NFQUEUE --queue-num 0 --queue-bypass
docker exec ids iptables -I OUTPUT -j NFQUEUE --queue-num 0 --queue-bypass
docker exec ids suricata -q 0 -S /etc/suricata/lab-rules/lab-ips.rules -l /var/log/suricata -D
```
Aguarde ~15 s e repita os ataques:
```bash
docker exec atacante curl -m 5 http://vitima/              # normal: FUNCIONA
docker exec atacante curl -m 5 http://vitima/admin/        # bloqueado: trava e expira
docker exec atacante curl -m 5 "http://vitima/?id=1%20OR%201=1"   # bloqueado
docker exec ids tail /var/log/suricata/fast.log            # veja [Drop]
```
✅ O acesso normal funciona, os ataques **expiram** (timeout) e o log mostra `[Drop]`.

**Perguntas**
1. Qual a diferença entre `alert` e `drop` no resultado?
2. **Falso positivo:** se um cliente legítimo tiver `/admin` na URL, o que acontece com ele? Quem sofre o prejuízo?
3. Por que muitas empresas começam com IDS e só depois ligam o IPS?
4. O IPS fica "no caminho" do tráfego. O que acontece se o Suricata cair? (dica: `--queue-bypass`)

---
## Fechamento — complete a tabela

| | IDS | IPS |
|---|---|---|
| Ação | | |
| Impacta o tráfego legítimo? | | |
| Risco principal | | |
| Ação da regra Suricata | `alert` | |

## Limpeza
```bash
docker compose down
```

## Problemas comuns
- **Nenhum alerta aparece:** esperou ~15 s depois de iniciar o Suricata? Ele carrega as regras antes de monitorar.
- **Mudei a regra e nada mudou:** reinicie o Suricata (`stop-suricata` + iniciar de novo).
- **`curl` trava mesmo sem ataque (Parte 3):** a fila está ativa mas o Suricata parou. Reinicie o lab com `docker compose down` e `up`.

## Usando Git Bash no Windows?
O Git Bash converte caminhos como `/var/log/...` em `C:/...` e quebra os comandos. Rode antes, uma vez por terminal:
```bash
export MSYS_NO_PATHCONV=1
```
(no PowerShell, CMD, Linux e macOS isso não é necessário)
