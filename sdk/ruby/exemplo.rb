# exemplo.rb: abre um .jsw e mostra as linhas em que <campo> vale <valor> (JSON), pelo indice (ou varrendo, com --varrer).
# ruby exemplo.rb dados.jsw id 2
require_relative "jsonw"

arquivo, campo, texto, modo = ARGV
JsonW::Leitor.abrir(arquivo) do |a|
  abort("campo #{campo} não existe") unless a.campos.include?(campo)
  a.indexar(campo) unless modo == "--varrer"
  $stdout.binmode
  a.chave(campo, JSON.parse(texto, quirks_mode: true)).each { |i| $stdout.write(a.json(i), "\n") }
end
