module linear_schedule_qualifier_probe;

import color : linearSchedule;

// Regression: public scalar template deduction must accept const lvalues while
// preserving the float/double-only scalar contract.

static assert(
    __traits(
        compiles,
        {
            const double start = 0.0;
            const double end = 1.0;
            auto values = linearSchedule!5(start, end);
            static assert(is(typeof(values) == double[5]));
        }
    )
);

static assert(
    __traits(
        compiles,
        {
            const float start = 0.0f;
            const float end = 1.0f;
            auto values = linearSchedule!5(start, end);
            static assert(is(typeof(values) == float[5]));
        }
    )
);

static assert(__traits(compiles, linearSchedule!5(0.0, 1.0)));
static assert(__traits(compiles, linearSchedule!5(0.0f, 1.0f)));

static assert(!__traits(compiles, linearSchedule!5(0, 1)));
static assert(!__traits(compiles, linearSchedule!5(0.0L, 1.0L)));

void main() {}
