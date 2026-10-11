// exact Euclidean distance transform (Felzenszwalb & Huttenlocher) of the sea to the nearest land; writes float16 at half resolution
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#define INF 1e20f
static void dt1(const float *f, float *d, int n, int *v, float *z) {
  int k = 0; v[0] = 0; z[0] = -INF; z[1] = INF;
  for (int q = 1; q < n; q++) {
    float s;
    for (;;) { s = ((f[q] + (float)q * q) - (f[v[k]] + (float)v[k] * v[k])) / (2.0f * q - 2.0f * v[k]); if (s <= z[k]) { k--; if (k < 0) { k = 0; break; } } else break; }
    if (k >= 0 && !(k == 0 && s <= z[0])) { k++; v[k] = q; z[k] = s; z[k + 1] = INF; }
    else { v[0] = q; z[0] = -INF; z[1] = INF; k = 0; }
  }
  k = 0;
  for (int q = 0; q < n; q++) { while (z[k + 1] < q) k++; d[q] = (float)(q - v[k]) * (q - v[k]) + f[v[k]]; }
}
static uint16_t f2h(float f) { // IEEE half
  union { float f; uint32_t u; } x; x.f = f; uint32_t s = (x.u >> 16) & 0x8000; int e = ((x.u >> 23) & 0xff) - 127 + 15; uint32_t m = x.u & 0x7fffff;
  if (e <= 0) return s; if (e >= 31) return s | 0x7bff; return s | (e << 10) | (m >> 13);
}
int main(int argc, char **argv) {
  int W = 4096, H = 2048, PAD = 256; int WP = W + 2 * PAD;
  uint8_t *ids = malloc(W * H * 2); FILE *fi = fopen(argv[1], "rb"); fread(ids, 1, W * H * 2, fi); fclose(fi);
  float *g = malloc(sizeof(float) * WP * H);
  for (int y = 0; y < H; y++) for (int x = 0; x < WP; x++) { int sx = ((x - PAD) % W + W) % W; int i = (y * W + sx) * 2; int land = (ids[i] | (ids[i + 1] << 8)) != 0; g[y * WP + x] = land ? 0.0f : INF; }
  int m = WP > H ? WP : H; int *v = malloc(sizeof(int) * m); float *z = malloc(sizeof(float) * (m + 1)); float *f = malloc(sizeof(float) * m), *d = malloc(sizeof(float) * m);
  for (int x = 0; x < WP; x++) { for (int y = 0; y < H; y++) f[y] = g[y * WP + x]; dt1(f, d, H, v, z); for (int y = 0; y < H; y++) g[y * WP + x] = d[y]; }
  for (int y = 0; y < H; y++) { for (int x = 0; x < WP; x++) f[x] = g[y * WP + x]; dt1(f, d, WP, v, z); for (int x = 0; x < WP; x++) g[y * WP + x] = d[x]; }
  int hw = W / 2, hh = H / 2; uint16_t *out = malloc(2 * hw * hh);
  for (int y = 0; y < hh; y++) for (int x = 0; x < hw; x++) {
    float s = 0; for (int dy = 0; dy < 2; dy++) for (int dx = 0; dx < 2; dx++) { float dd = g[(2 * y + dy) * WP + PAD + 2 * x + dx]; if (dd > 1e10f) dd = 4000.0f; s += sqrtf(dd); }
    s *= 0.25f; if (s > 1000.0f) s = 1000.0f; out[y * hw + x] = f2h(s);
  }
  FILE *fo = fopen(argv[2], "wb"); fwrite(out, 2, hw * hh, fo); fclose(fo);
  return 0;
}
