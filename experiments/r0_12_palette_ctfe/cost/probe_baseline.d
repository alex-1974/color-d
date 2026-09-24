module probe_baseline;

import probe_common;

/*
 * Parse/typecheck baseline.
 *
 * Deliberately no palette CTFE instantiation.
 */
enum baselineMarker = 1;

static assert(baselineMarker == 1);
