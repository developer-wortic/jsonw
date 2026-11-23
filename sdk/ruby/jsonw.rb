# jsonW (json Wondrous) para Ruby, por cima da ABI C (libjsonw) com o Fiddle da biblioteca padrao (sem gem de fora).
#
#   require_relative "jsonw"
#   JsonW::Leitor.abrir("dados.jsw") { |a| puts a.esquema; a.each { |linha| p linha } }   # cada linha como Hash (JSON)
#   JsonW::Escritor.criar("novo.jsw", "id:i64,nome:texto") { |w| w.gravar({ "id" => 1, "nome" => "x" }) }
#   a.avaliar({ "cosseno" => { "campo" => "vet", "consulta" => [0.5, -1, 2, 0.25] } }, 5)   # [{"linha"=>3, "nota"=>0.98}]
#   JsonW.escolher([0.2, 0.9, 0.5], 2)                                                     # [1, 2]
#   JsonW::Reconhecedor.abrir("termos.jsw") { |r| r.reconhecer("texto") }                  # {"termos"=>[...], "sinais"=>[...]}
require "fiddle"
require "json"
require "rbconfig"

module JsonW
  class Erro < StandardError; end
  class LinhaOculta < Erro; end   # linha de outro tenant depois de visao (-3 na ABI)

  def self.plataforma   # o nome da pasta de bin/ no pacote publico
    so = RbConfig::CONFIG["host_os"] =~ /darwin/ ? "macos" : RbConfig::CONFIG["host_os"] =~ /mswin|mingw/ ? "windows" : "linux"
    maq = RbConfig::CONFIG["host_cpu"].downcase
    maq = { "aarch64" => "arm64", "arm64e" => "arm64", "amd64" => "x86_64", "x64" => "x86_64" }.fetch(maq, maq)
    "#{so}-#{maq}"
  end

  # a biblioteca: JSONW_LIB (caminho inteiro), ao lado deste arquivo, na pasta sdk ou em bin/<plataforma> do pacote
  def self.carregar
    return Fiddle.dlopen(ENV["JSONW_LIB"]) if ENV["JSONW_LIB"] && !ENV["JSONW_LIB"].empty?
    aqui = __dir__
    nomes = Gem.win_platform? ? %w[libjsonw.dll jsonw.dll] : %w[libjsonw.dylib libjsonw.so]
    [aqui, File.join(aqui, ".."), File.join(aqui, "..", ".."), File.join(aqui, "..", "..", "bin", plataforma)].each do |pasta|
      nomes.each do |n|
        cam = File.join(pasta, n)
        next unless File.exist?(cam)
        begin
          return Fiddle.dlopen(cam)
        rescue Fiddle::DLError
          next
        end
      end
    end
    raise Erro, "libjsonw nao encontrada para #{plataforma}: aponte JSONW_LIB para a biblioteca ou copie-a para a pasta sdk"
  end

  P = Fiddle::TYPE_VOIDP; S = Fiddle::TYPE_SIZE_T; I = Fiddle::TYPE_INT; L = Fiddle::TYPE_LONG_LONG; V = Fiddle::TYPE_VOID
  LIB = carregar
  ASSINATURAS = {
    versao: [[], P], abrir: [[P, P, S], P], fechar: [[P], V], linhas: [[P], L], campos: [[P], I], esquema: [[P], P],
    campo_nome: [[P, I], P], linha_json: [[P, L, P, S], L], linha_texto: [[P, L, P, S], L], campo_json: [[P, L, I, P, S], L],
    conferir: [[P, P, S], I], criar: [[P, P, P, S], P], opcoes: [[P, I, I, I], I], gravar_json: [[P, P, S, P, S], I],
    descarregar: [[P], I], fechar_escritor: [[P], I], abandonar: [[P], I], visao: [[P, P, P, S], I],
    avaliar: [[P, P, S, S, P, S, P, S], L], escolher: [[P, S, S, P], L], reconhecedor: [[P, P, S], P],
    reconhecedor_fechar: [[P], V], reconhecer: [[P, P, S, P, S], L],
    indexar: [[P, I], I], tem_indice: [[P, I], I], chave: [[P, I, P, S, P, S], L]
  }.freeze
  F = ASSINATURAS.each_with_object({}) { |(n, (a, r)), h| h[n] = Fiddle::Function.new(LIB["jsonw_#{n}"], a, r) }.freeze

  def self.cstr(ptr); ptr.null? ? "" : ptr.to_s.force_encoding(Encoding::UTF_8); end
  def self.versao; cstr(F[:versao].call); end

  def self.erro_buf; Fiddle::Pointer.malloc(300, Fiddle::RUBY_FREE); end
  def self.erro_de(buf); buf.to_s.force_encoding(Encoding::UTF_8); end

  # chama fn(*args, saida, cap) crescendo a saida enquanto a ABI pedir mais (-2); -3 = linha oculta pela visao
  def self.texto(fn, *args)
    cap = 1 << 16
    loop do
      b = Fiddle::Pointer.malloc(cap, Fiddle::RUBY_FREE)
      n = F[fn].call(*args, b, cap)
      if n == -2 then cap *= 4; next end
      raise LinhaOculta, "linha oculta pela visao" if n == -3
      raise Erro, "linha ou campo ilegivel" if n.negative?
      return b.to_s(n).force_encoding(Encoding::UTF_8)
    end
  end

  # posicoes das k maiores notas (maior primeiro; empate pela menor posicao; NaN e a pior)
  def self.escolher(notas, k)
    v = Fiddle::Pointer[notas.map(&:to_f).pack("d*") + "\0" * 8]
    out = Fiddle::Pointer.malloc(8 * [k, 1].max, Fiddle::RUBY_FREE)
    m = F[:escolher].call(v, notas.size, k, out)
    m.positive? ? out.to_s(8 * m).unpack("Q*") : []
  end

  class Leitor
    include Enumerable
    attr_reader :linhas, :esquema, :campos

    def self.abrir(caminho)
      a = new(caminho)
      return a unless block_given?
      begin yield a ensure a.fechar end
    end

    def initialize(caminho)
      e = JsonW.erro_buf
      @a = F[:abrir].call(caminho, e, 300)
      raise Erro, JsonW.erro_de(e) if @a.null?
      @linhas = F[:linhas].call(@a)
      ler_esquema
    end

    def ler_esquema
      @esquema = JsonW.cstr(F[:esquema].call(@a))
      @campos = (0...F[:campos].call(@a)).map { |i| JsonW.cstr(F[:campo_nome].call(@a, i)) }
    end
    private :ler_esquema

    def fechar
      F[:fechar].call(@a) if @a && !@a.null?
      @a = nil
    end

    def json(i); JsonW.texto(:linha_json, @a, i); end
    def texto(i); JsonW.texto(:linha_texto, @a, i); end
    def linha(i); JSON.parse(json(i)); end
    def campo(i, campo); JSON.parse(JsonW.texto(:campo_json, @a, i, indice_de(campo))); end
    def size; @linhas; end

    def conferir
      e = JsonW.erro_buf
      raise Erro, JsonW.erro_de(e) unless F[:conferir].call(@a, e, 300).zero?
      true
    end

    def each   # com visao, as linhas de outro tenant ficam de fora
      return enum_for(:each) unless block_given?
      @linhas.times do |i|
        begin
          yield linha(i)
        rescue LinhaOculta
          next
        end
      end
    end

    # BUSCAR POR CHAVE: as linhas em que <campo> vale <valor>, em ordem; com indexar(campo), sem varrer
    def indexar(campo)
      raise Erro, "campo sem indice" unless F[:indexar].call(@a, indice_de(campo)).zero?
      self
    end

    def tem_indice?(campo); F[:tem_indice].call(@a, indice_de(campo)) == 1; end

    def chave(campo, valor)
      v = JSON.generate(valor).b
      k = indice_de(campo); cap = 16
      loop do
        out = Fiddle::Pointer.malloc(8 * cap, Fiddle::RUBY_FREE)
        n = F[:chave].call(@a, k, v, v.bytesize, out, cap)
        raise Erro, "valor nao e do tipo do campo" if n == -2
        raise Erro, "campo invalido" if n.negative?
        return n.zero? ? [] : out.to_s(8 * n).unpack("Q*") if n <= cap
        cap = n
      end
    end

    def indice_de(campo); campo.is_a?(Integer) ? campo : (@campos.index(campo) || -1); end
    private :indice_de

    # trava o que a sessao ve ("pessoal vendas tenant:42"); nao destrava
    def visao(escopos)
      e = JsonW.erro_buf
      raise Erro, JsonW.erro_de(e) unless F[:visao].call(@a, escopos, e, 300).zero?
      ler_esquema
    end

    # as k melhores linhas pelo pedido (Hash ou texto JSON), como a ABI devolve: [{"linha", "nota"}]
    def avaliar_json(pedido, k = 10)
      p = (pedido.is_a?(String) ? pedido : JSON.generate(pedido)).b
      cap = 1 << 16
      loop do
        b = Fiddle::Pointer.malloc(cap, Fiddle::RUBY_FREE); e = JsonW.erro_buf
        n = F[:avaliar].call(@a, p, p.bytesize, k, b, cap, e, 300)
        if n == -2 then cap *= 4; next end
        raise Erro, JsonW.erro_de(e) if n.negative?
        return b.to_s(n).force_encoding(Encoding::UTF_8)
      end
    end

    def avaliar(pedido, k = 10); JSON.parse(avaliar_json(pedido, k)); end
  end

  class Escritor
    def self.criar(caminho, esquema, **op)
      w = new(caminho, esquema, **op)
      return w unless block_given?
      ok = false
      begin
        yield w
        ok = true
      ensure
        ok ? w.fechar : w.abandonar   # saiu por erro: o destino fica como estava
      end
    end

    def initialize(caminho, esquema, compressao: 1, hash_alg: 0, bloco_kb: 0)
      e = JsonW.erro_buf
      @w = F[:criar].call(caminho, esquema, e, 300)
      raise Erro, JsonW.erro_de(e) if @w.null?
      F[:opcoes].call(@w, compressao, hash_alg, bloco_kb)
    end

    def gravar_texto(texto)
      b = texto.b; e = JsonW.erro_buf
      raise Erro, JsonW.erro_de(e) unless F[:gravar_json].call(@w, b, b.bytesize, e, 300).zero?
    end

    def gravar(obj); gravar_texto(JSON.generate(obj)); end
    def descarregar; F[:descarregar].call(@w); end

    def abandonar   # desiste: fecha sem publicar; o destino fica como estava
      F[:abandonar].call(@w) if @w
      @w = nil
    end

    def fechar
      return unless @w
      r = F[:fechar_escritor].call(@w); @w = nil
      raise Erro, "nao gravou tudo" unless r.zero?
    end
  end

  # a tabela de termos (termo:texto,forma:dic,sinal:dic,peso:f32,idioma:dic,origem:dic) vira o reconhecedor
  class Reconhecedor
    def self.abrir(caminho)
      r = new(caminho)
      return r unless block_given?
      begin yield r ensure r.fechar end
    end

    def initialize(caminho)
      e = JsonW.erro_buf
      @r = F[:reconhecedor].call(caminho, e, 300)
      raise Erro, JsonW.erro_de(e) if @r.null?
    end

    def fechar
      F[:reconhecedor_fechar].call(@r) if @r
      @r = nil
    end

    def reconhecer_json(texto)
      t = texto.b; cap = 1 << 16
      loop do
        b = Fiddle::Pointer.malloc(cap, Fiddle::RUBY_FREE)
        n = F[:reconhecer].call(@r, t, t.bytesize, b, cap)
        if n == -2 then cap *= 4; next end
        raise Erro, "reconhecedor fechado ou texto ilegivel" if n.negative?
        return b.to_s(n).force_encoding(Encoding::UTF_8)
      end
    end

    def reconhecer(texto); JSON.parse(reconhecer_json(texto)); end
  end
end

if $PROGRAM_NAME == __FILE__   # ruby jsonw.rb arq.jsw -> JSONL; --avaliar arq pedido k; --reconhecer termos.jsw texto; --gravar esquema entrada.jsonl saida.jsw
  $stdout.binmode
  case ARGV[0]
  when "--avaliar" then JsonW::Leitor.abrir(ARGV[1]) { |a| puts a.avaliar_json(ARGV[2], ARGV[3].to_i) }
  when "--reconhecer" then JsonW::Reconhecedor.abrir(ARGV[1]) { |r| puts r.reconhecer_json(ARGV[2]) }
  when "--visao"   # --visao arq escopos pedido k: campos, as linhas visiveis (JSONL) e o avaliar
    JsonW::Leitor.abrir(ARGV[1]) do |a|
      a.visao(ARGV[2]); puts a.campos.join(",")
      a.linhas.times do |i|
        begin
          $stdout.write(a.json(i), "\n")
        rescue JsonW::LinhaOculta
          next
        end
      end
      puts a.avaliar_json(ARGV[3], ARGV[4].to_i)
    end
  when "--gravar"
    JsonW::Escritor.criar(ARGV[3], ARGV[1]) { |w| File.foreach(ARGV[2], encoding: "UTF-8") { |l| w.gravar_texto(l) unless l.strip.empty? } }
  else JsonW::Leitor.abrir(ARGV[0]) { |a| a.linhas.times { |i| $stdout.write(a.json(i), "\n") } }
  end
end
