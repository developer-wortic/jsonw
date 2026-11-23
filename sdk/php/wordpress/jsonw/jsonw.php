<?php
/**
 * Plugin Name:       jsonW
 * Plugin URI:        https://jsonw.org
 * Description:       Lê arquivos .jsw no WordPress (temas, plugins e WP-CLI) pelo SDK de PHP do jsonW.
 * Version:           1.3.14
 * Requires at least: 6.6
 * Requires PHP:      8.4
 * Author:            Wortic
 * Author URI:        https://wortic.com.br
 * License:           Licença de Uso Sustentável do jsonW
 * Text Domain:       jsonw
 */

declare(strict_types=1);

defined('ABSPATH') || exit;

if (!extension_loaded('ffi')) {
    add_action('admin_notices', static function (): void {
        echo '<div class="notice notice-error"><p>', esc_html__('jsonW precisa da extensão FFI do PHP.', 'jsonw'), '</p></div>';
    });
    return;
}

require_once is_file(__DIR__ . '/sdk/jsonw.php') ? __DIR__ . '/sdk/jsonw.php' : __DIR__ . '/../../jsonw.php';

if (defined('WP_CLI') && WP_CLI) {
    WP_CLI::add_command('jsonw', new class {
        /**
         * Mostra as linhas de um .jsw em JSON.
         *
         * ## OPTIONS
         *
         * <arquivo>
         * : O arquivo .jsw.
         *
         * [--limite=<n>]
         * : Quantas linhas, a partir da primeira.
         * ---
         * default: 20
         * ---
         */
        public function ver(array $args, array $opcoes): void
        {
            $a = new JsonW\Leitor($args[0]);
            $limite = min($a->linhas, (int) $opcoes['limite']);
            for ($i = 0; $i < $limite; $i++) {
                WP_CLI::line($a->json($i));
            }
        }

        /**
         * Confere a custódia do arquivo (crc32c e hash em cadeia).
         *
         * <arquivo>
         * : O arquivo .jsw.
         */
        public function conferir(array $args): void
        {
            $a = new JsonW\Leitor($args[0]);
            $a->conferir();
            WP_CLI::success(sprintf('%d linhas conferidas', $a->linhas));
        }

        /**
         * As linhas em que um campo vale um valor, pelo índice.
         *
         * <arquivo>
         * : O arquivo .jsw.
         *
         * <campo>
         * : O nome do campo.
         *
         * <valor>
         * : O valor em JSON (2, "RJ").
         */
        public function chave(array $args): void
        {
            [$arquivo, $campo, $valor] = $args;
            $a = (new JsonW\Leitor($arquivo))->indexar($campo);
            foreach ($a->chave($campo, json_decode($valor, true, 512, JSON_THROW_ON_ERROR)) as $i) {
                WP_CLI::line($a->json($i));
            }
        }
    });
}
