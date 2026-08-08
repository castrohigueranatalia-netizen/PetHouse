#!/usr/bin/env python3
"""Construye index.html autocontenido: concatena las partes e inyecta
las imágenes como data URIs (base64) reemplazando {{IMG:token}}."""
import base64, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = ['part1_head.html', 'part2_js_data.html', 'part2b_map.js', 'part3_js_views.html', 'part4_js_actions.html']

def main():
    html = ''
    for p in PARTS:
        with open(os.path.join(HERE, p), encoding='utf-8') as f:
            html += f.read()

    tokens = {}
    for fname in os.listdir(os.path.join(HERE, '_src')):
        if fname.endswith('.bin'):
            token = fname[:-4]
            with open(os.path.join(HERE, '_src', fname), 'rb') as f:
                data = f.read()
            mime = 'image/png' if token == 'logo' else 'image/jpeg'
            tokens[token] = f'data:{mime};base64,' + base64.b64encode(data).decode('ascii')

    missing = []
    for t in tokens:
        if ('{{IMG:' + t + '}}') not in html:
            missing.append(t)
    if missing:
        print('ERROR: tokens no encontrados en el HTML:', missing)
        sys.exit(1)

    for t, uri in tokens.items():
        html = html.replace('{{IMG:' + t + '}}', uri)

    leftover = [t for t in ('logo','hero','g1','g2','v1','v2','c1','c2','a1','a2','paseo') if '{{IMG:' + t + '}}' in html]
    if leftover:
        print('ERROR: tokens sin reemplazar:', leftover)
        sys.exit(1)

    out = os.path.join(HERE, 'index.html')
    with open(out, 'w', encoding='utf-8') as f:
        f.write(html)
    print(f'OK → {out} ({len(html)/1024:.0f} KB)')

if __name__ == '__main__':
    main()
