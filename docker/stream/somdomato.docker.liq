#!/usr/bin/env liquidsoap
# Versão Docker do somdomato.liq
# Diferenças da produção:
#   - API Next.js: nextjs:3000 (Docker DNS) em vez de localhost:3000
#   - Icecast host: icecast (Docker DNS) em vez de localhost

settings.init.allow_root := true
settings.harbor.bind_addrs := ["0.0.0.0"]
settings.log.stdout := true
settings.log.level := 3

# Input ao vivo (DJ broadcast)
live = input.harbor("aovivo", port=8010, user="dj", password="hackme")

# Próxima música via API do Next.js
def next()
  def request_function() =
    result = process.read.lines("curl -sf http://nextjs:3000/api/music")
    json = list.hd(default="", result)

    path = list.hd(default="", process.read.lines("echo '#{json}' | jq -r '.path'"))
    title = list.hd(default="", process.read.lines("echo '#{json}' | jq -r '.title'"))
    artist = list.hd(default="", process.read.lines("echo '#{json}' | jq -r '.artist'"))

    log("Próxima música: #{path}")

    uri = "annotate:title=\"#{title}\",artist=\"#{artist}\":#{path}"
    request.create(uri)
  end
  request.dynamic(id="next_track", request_function)
end

autodj = next()

# Prioridade: ao vivo > autodj
radio = fallback(track_sensitive=false, [live, autodj])

output.icecast(
  %mp3(bitrate=128, samplerate=44100, id3v2=true),
  name = "Radio Som do Mato",
  description = "A mais sertaneja!",
  genre = "Sertanejo",
  url = "https://somdomato.com",
  host = "icecast",
  port = 8000,
  password = "hackme",
  mount = "/radio.mp3",
  encoding = "UTF-8",
  mksafe(radio))
