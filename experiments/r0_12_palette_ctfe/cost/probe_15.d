module probe_15;

import probe_common;

enum size_t families = 3;
enum size_t tonesPerFamily = 5;

enum bundle =
    buildProbe!(
        double,
        families,
        tonesPerFamily
    )();

static assert(bundle.raw.length == families);
static assert(bundle.raw[0].length == tonesPerFamily);

static assert(
    allMappingsSuccessful!(
        double,
        families,
        tonesPerFamily
    )(bundle.mapped)
);


static assert(
    bundle.encoded[0][0].r ==
    bundle.encoded[0][0].r
);
