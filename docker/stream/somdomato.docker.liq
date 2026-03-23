#!/usr/bin/env liquidsoap
# Versão Docker do somdomato.liq
# Diferenças da produção:
#   - API Next.js: nextjs:3000 (Docker DNS) em vez de localhost:3000
#   - Icecast host: icecast (Docker DNS) em vez de localhost
#   - HTTP handlers na porta 8081 (evita conflito com nginx na 8080)

settings.init.allow_root := true
settings.harbor.bind_addrs := ["0.0.0.0"]
settings.log.stdout := true
settings.log.level := 3

# Input ao vivo (DJ broadcast)
live = input.harbor("aovivo", port=8010, user="dj", password="hackme")

# Função para buscar próxima música do Next.js por gênero
def next(genre) =
  def request_function() =
    result = process.read.lines("curl -sf http://nextjs:3000/api/music?genre=#{genre}")
    json = list.hd(default="", result)

    path = list.hd(default="", process.read.lines("echo '#{json}' | jq -r '.path'"))
    title = list.hd(default="", process.read.lines("echo '#{json}' | jq -r '.title'"))
    artist = list.hd(default="", process.read.lines("echo '#{json}' | jq -r '.artist'"))
    song_id = list.hd(default="", process.read.lines("echo '#{json}' | jq -r '.id'"))
    was_requested = list.hd(default="0", process.read.lines("echo '#{json}' | jq -r 'if .wasRequested then \"1\" else \"0\" end'"))

    if path == "" or path == "null" then
      log("[#{genre}] Nenhuma música retornada pela API - aguardando 5s")
      null()
    else
      log("[#{genre}] Próxima música: #{path}")
      uri = "annotate:title=\"#{title}\",artist=\"#{artist}\",song_id=\"#{song_id}\",was_requested=\"#{was_requested}\":#{path}"
      req = request.create(uri)
      if req != null() then
        log("[#{genre}] Request criada com sucesso")
      else
        log("[#{genre}] Falha ao criar request para #{uri}")
      end
      req
    end
  end
  request.dynamic(id="next_track_#{genre}", retry_delay=5.0, timeout=60.0, request_function)
end

# Notificar API quando música começa a tocar
def notify_started(genre, m) =
  song_id = m["song_id"]
  was_requested = m["was_requested"]
  if song_id != "" and song_id != "null" then
    api_url = "http://nextjs:3000/api/music/started?songId=#{song_id}&genre=#{genre}&wasRequested=#{was_requested}"
    log("[#{genre}] Notificando início: songId=#{song_id}")
    ignore(process.read.lines("curl -sf -X POST '#{api_url}'"))
  end
end

# AutoDJ por gênero
autodj_geral     = next("geral")
autodj_gaucha    = next("gaucha")
autodj_modao     = next("modao")
autodj_arrocha   = next("arrocha")
autodj_romantico = next("romantico")
autodj_forro     = next("forro")

# Callbacks on_track
autodj_geral.on_track(fun (m) -> notify_started("geral", m))
autodj_gaucha.on_track(fun (m) -> notify_started("gaucha", m))
autodj_modao.on_track(fun (m) -> notify_started("modao", m))
autodj_arrocha.on_track(fun (m) -> notify_started("arrocha", m))
autodj_romantico.on_track(fun (m) -> notify_started("romantico", m))
autodj_forro.on_track(fun (m) -> notify_started("forro", m))

# Fila manual (pedidos) — apenas para geral
queue = request.queue(id="manual_queue")

# Skip handler HTTP
def skip_handler(_, req) =
  log("Skip recebido via HTTP")
  autodj_geral.skip()
  autodj_gaucha.skip()
  autodj_modao.skip()
  autodj_arrocha.skip()
  autodj_romantico.skip()
  autodj_forro.skip()
  ignore(req.status_code(200))
  ignore(req.content_type("text/plain"))
  ignore(req.html("OK"))
end

# Play handler — injeta música específica no geral
def play_handler(_, req) =
  log("Play específico recebido via HTTP")
  body = req.data("")
  path   = list.hd(default="", process.read.lines("echo '#{body}' | jq -r '.path'"))
  title  = list.hd(default="", process.read.lines("echo '#{body}' | jq -r '.title'"))
  artist = list.hd(default="", process.read.lines("echo '#{body}' | jq -r '.artist'"))
  log("Injetando: #{path}")
  uri_annotate = "annotate:title=\"#{title}\",artist=\"#{artist}\":#{path}"
  request_obj = request.create(uri_annotate)
  queue.push(request_obj)
  autodj_geral.skip()
  ignore(req.status_code(200))
  ignore(req.content_type("text/plain"))
  ignore(req.html("OK"))
end

harbor.http.register(port=8081, method="POST", "/skip", skip_handler)
harbor.http.register(port=8081, method="POST", "/play", play_handler)

# Rádios: geral tem live + queue; demais apenas autodj
radio_geral     = fallback(track_sensitive=false, [live, queue, autodj_geral])
radio_gaucha    = fallback(track_sensitive=false, [autodj_gaucha])
radio_modao     = fallback(track_sensitive=false, [autodj_modao])
radio_arrocha   = fallback(track_sensitive=false, [autodj_arrocha])
radio_romantico = fallback(track_sensitive=false, [autodj_romantico])
radio_forro     = fallback(track_sensitive=false, [autodj_forro])

# Outputs Icecast
output.icecast(%mp3(bitrate=128, samplerate=44100, id3v2=true),
  name="Radio Som do Mato - Geral", description="A mais sertaneja - Geral",
  genre="Sertanejo", url="https://somdomato.com",
  host="icecast", port=8000, password="hackme", mount="/geral",
  encoding="UTF-8", mksafe(radio_geral))

output.icecast(%mp3(bitrate=128, samplerate=44100, id3v2=true),
  name="Radio Som do Mato - Gaúcha", description="A mais sertaneja - Gaúcha",
  genre="Sertanejo Gaúcho", url="https://somdomato.com",
  host="icecast", port=8000, password="hackme", mount="/gaucha",
  encoding="UTF-8", mksafe(radio_gaucha))

output.icecast(%mp3(bitrate=128, samplerate=44100, id3v2=true),
  name="Radio Som do Mato - Modão", description="A mais sertaneja - Modão",
  genre="Modão", url="https://somdomato.com",
  host="icecast", port=8000, password="hackme", mount="/modao",
  encoding="UTF-8", mksafe(radio_modao))

output.icecast(%mp3(bitrate=128, samplerate=44100, id3v2=true),
  name="Radio Som do Mato - Arrocha", description="A mais sertaneja - Arrocha",
  genre="Arrocha", url="https://somdomato.com",
  host="icecast", port=8000, password="hackme", mount="/arrocha",
  encoding="UTF-8", mksafe(radio_arrocha))

output.icecast(%mp3(bitrate=128, samplerate=44100, id3v2=true),
  name="Radio Som do Mato - Romântico", description="A mais sertaneja - Romântico",
  genre="Romântico", url="https://somdomato.com",
  host="icecast", port=8000, password="hackme", mount="/romantico",
  encoding="UTF-8", mksafe(radio_romantico))

output.icecast(%mp3(bitrate=128, samplerate=44100, id3v2=true),
  name="Radio Som do Mato - Forró", description="A mais sertaneja - Forró",
  genre="Forró", url="https://somdomato.com",
  host="icecast", port=8000, password="hackme", mount="/forro",
  encoding="UTF-8", mksafe(radio_forro))
