// bounding box of every province in the id map (4096 x 2048, u16 little endian, 0 = sea, id - 1 = province): x0 y0 x1 y1 as int16, province order; -1 for a province with no texel
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
int main(int argc, char **argv) {
  int W = 4096, H = 2048, P = atoi(argv[3]);
  uint8_t *ids = malloc(W * H * 2); FILE *fi = fopen(argv[1], "rb"); if (fread(ids, 1, W * H * 2, fi) != (size_t)W * H * 2) return 1; fclose(fi);
  int16_t *bb = malloc(sizeof(int16_t) * 4 * P);
  for (int i = 0; i < P; i++) { bb[4 * i] = 32767; bb[4 * i + 1] = 32767; bb[4 * i + 2] = -1; bb[4 * i + 3] = -1; }
  for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
    int id = ids[(y * W + x) * 2] | (ids[(y * W + x) * 2 + 1] << 8); if (id == 0) continue; int p = id - 1; if (p >= P) continue;
    if (x < bb[4 * p]) bb[4 * p] = x; if (y < bb[4 * p + 1]) bb[4 * p + 1] = y; if (x > bb[4 * p + 2]) bb[4 * p + 2] = x; if (y > bb[4 * p + 3]) bb[4 * p + 3] = y;
  }
  for (int i = 0; i < P; i++) if (bb[4 * i + 2] < 0) { bb[4 * i] = bb[4 * i + 1] = bb[4 * i + 2] = bb[4 * i + 3] = -1; }
  FILE *fo = fopen(argv[2], "wb"); fwrite(bb, sizeof(int16_t), 4 * P, fo); fclose(fo); return 0;
}
