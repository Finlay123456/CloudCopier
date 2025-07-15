#include "State.h"
bool paused = false;
bool isPaused() { return paused; }
void togglePaused() { paused = !paused; }
