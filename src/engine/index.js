import { Game } from './game.js';
import { endTurn, spawnRebel, rebelTurn, checkVictory } from './turn.js';
import { runAI, aiAcceptsPeace, aiAcceptsPact } from './ai.js';
import { stateHash } from './hash.js';
Object.assign(Game.prototype, {
  endTurn() { return endTurn(this); },
  runAI() { return runAI(this); },
  spawnRebel(p) { return spawnRebel(this, p); },
  rebelTurn() { return rebelTurn(this); },
  checkVictory() { return checkVictory(this); },
  aiAcceptsPeace(t, p, k) { return aiAcceptsPeace(this, t, p, k); },
  aiAcceptsPact(t, p, r) { return aiAcceptsPact(this, t, p, r); },
  hash() { return stateHash(this); },
});
export { Game };
export * from './data.js';
export { Rng } from './rng.js';
