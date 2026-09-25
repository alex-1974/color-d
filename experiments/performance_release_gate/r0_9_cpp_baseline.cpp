#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string_view>
#include <type_traits>

template <typename T>
concept ColorScalar =
    std::is_same_v<T, float> ||
    std::is_same_v<T, double>;

template <ColorScalar T>
struct SRgb
{
    T r;
    T g;
    T b;
};

template <ColorScalar T>
struct LinearSRgb
{
    T r;
    T g;
    T b;
};

template <ColorScalar T>
struct Wcag2Measurement
{
    T value;
    bool valid;
};

template <ColorScalar T>
struct CompactWcag2Measurement
{
    T value;

    bool valid() const noexcept
    {
        return value == value;
    }
};

static_assert(sizeof(CompactWcag2Measurement<float>) == sizeof(float));
static_assert(sizeof(CompactWcag2Measurement<double>) == sizeof(double));

#if defined(__GNUC__) || defined(__clang__)
#  define ALWAYS_INLINE inline __attribute__((always_inline))
#else
#  define ALWAYS_INLINE inline
#endif

template <ColorScalar T>
constexpr T magnitude(T value) noexcept
{
    return value < T(0) ? -value : value;
}

template <ColorScalar T>
constexpr T signOf(T value) noexcept
{
    return value < T(0) ? T(-1) : T(1);
}

template <ColorScalar T>
constexpr bool finiteValue(T value) noexcept
{
    return
        value == value &&
        value <= std::numeric_limits<T>::max() &&
        value >= -std::numeric_limits<T>::max();
}

template <ColorScalar T>
constexpr bool isValidWcag2SrgbDomain(SRgb<T> color) noexcept
{
    return
        finiteValue(color.r) &&
        finiteValue(color.g) &&
        finiteValue(color.b) &&

        color.r >= T(0) &&
        color.r <= T(1) &&

        color.g >= T(0) &&
        color.g <= T(1) &&

        color.b >= T(0) &&
        color.b <= T(1);
}

template <ColorScalar T>
constexpr bool isValidWcag2LinearSrgbDomain(LinearSRgb<T> color) noexcept
{
    return
        finiteValue(color.r) &&
        finiteValue(color.g) &&
        finiteValue(color.b) &&

        color.r >= T(0) &&
        color.r <= T(1) &&

        color.g >= T(0) &&
        color.g <= T(1) &&

        color.b >= T(0) &&
        color.b <= T(1);
}

template <ColorScalar T>
T srgbToLinearComponent(T encoded) noexcept
{
    const T absEncoded = magnitude(encoded);

    if (absEncoded <= T(0.04045))
        return encoded / T(12.92);

    const T base =
        (absEncoded + T(0.055)) /
        T(1.055);

    return
        signOf(encoded) *
        static_cast<T>(std::pow(base, T(2.4)));
}

template <ColorScalar T>
LinearSRgb<T> toLinear(SRgb<T> color) noexcept
{
    return LinearSRgb<T>{
        srgbToLinearComponent(color.r),
        srgbToLinearComponent(color.g),
        srgbToLinearComponent(color.b)
    };
}

template <ColorScalar T>
constexpr T wcag2RelativeLuminance(LinearSRgb<T> color) noexcept
{
    return
        T(0.2126) * color.r +
        T(0.7152) * color.g +
        T(0.0722) * color.b;
}

template <ColorScalar T>
T wcag2RelativeLuminance(SRgb<T> color) noexcept
{
    return wcag2RelativeLuminance(toLinear(color));
}

template <ColorScalar T>
constexpr T wcag2ContrastFromLuminance(T a, T b) noexcept
{
    const bool aIsLighter = a >= b;

    const T lighter =
        aIsLighter ? a : b;

    const T darker =
        aIsLighter ? b : a;

    return
        (lighter + T(0.05)) /
        (darker + T(0.05));
}

template <ColorScalar T>
T wcag2ContrastRatio(SRgb<T> a, SRgb<T> b) noexcept
{
    return wcag2ContrastFromLuminance(
        wcag2RelativeLuminance(a),
        wcag2RelativeLuminance(b)
    );
}

template <ColorScalar T>
ALWAYS_INLINE Wcag2Measurement<T>
checkedWcag2RelativeLuminance(LinearSRgb<T> color) noexcept
{
    if (!isValidWcag2LinearSrgbDomain(color))
    {
        return Wcag2Measurement<T>{
            std::numeric_limits<T>::quiet_NaN(),
            false
        };
    }

    return Wcag2Measurement<T>{
        wcag2RelativeLuminance(color),
        true
    };
}

template <ColorScalar T>
ALWAYS_INLINE Wcag2Measurement<T>
checkedWcag2RelativeLuminance(SRgb<T> color) noexcept
{
    if (!isValidWcag2SrgbDomain(color))
    {
        return Wcag2Measurement<T>{
            std::numeric_limits<T>::quiet_NaN(),
            false
        };
    }

    return Wcag2Measurement<T>{
        wcag2RelativeLuminance(color),
        true
    };
}

template <ColorScalar T>
ALWAYS_INLINE Wcag2Measurement<T>
checkedWcag2ContrastRatio(SRgb<T> a, SRgb<T> b) noexcept
{
    if (
        !isValidWcag2SrgbDomain(a) ||
        !isValidWcag2SrgbDomain(b))
    {
        return Wcag2Measurement<T>{
            std::numeric_limits<T>::quiet_NaN(),
            false
        };
    }

    return Wcag2Measurement<T>{
        wcag2ContrastRatio(a, b),
        true
    };
}

template <ColorScalar T>
CompactWcag2Measurement<T>
compactCheckedWcag2RelativeLuminance(LinearSRgb<T> color) noexcept
{
    if (!isValidWcag2LinearSrgbDomain(color))
    {
        return CompactWcag2Measurement<T>{
            std::numeric_limits<T>::quiet_NaN()
        };
    }

    return CompactWcag2Measurement<T>{
        wcag2RelativeLuminance(color)
    };
}

template <ColorScalar T>
CompactWcag2Measurement<T>
compactCheckedWcag2RelativeLuminance(SRgb<T> color) noexcept
{
    if (!isValidWcag2SrgbDomain(color))
    {
        return CompactWcag2Measurement<T>{
            std::numeric_limits<T>::quiet_NaN()
        };
    }

    return CompactWcag2Measurement<T>{
        wcag2RelativeLuminance(color)
    };
}

template <ColorScalar T>
CompactWcag2Measurement<T>
compactCheckedWcag2ContrastRatio(SRgb<T> a, SRgb<T> b) noexcept
{
    if (
        !isValidWcag2SrgbDomain(a) ||
        !isValidWcag2SrgbDomain(b))
    {
        return CompactWcag2Measurement<T>{
            std::numeric_limits<T>::quiet_NaN()
        };
    }

    return CompactWcag2Measurement<T>{
        wcag2ContrastRatio(a, b)
    };
}

template <ColorScalar T>
bool tryWcag2RelativeLuminance(
    LinearSRgb<T> color,
    T& value) noexcept
{
    if (!isValidWcag2LinearSrgbDomain(color))
        return false;

    value = wcag2RelativeLuminance(color);
    return true;
}

template <ColorScalar T>
T nanCheckedWcag2RelativeLuminance(
    LinearSRgb<T> color) noexcept
{
    if (!isValidWcag2LinearSrgbDomain(color))
        return std::numeric_limits<T>::quiet_NaN();

    return wcag2RelativeLuminance(color);
}

template <ColorScalar T>
bool tryWcag2RelativeLuminance(
    SRgb<T> color,
    T& value) noexcept
{
    if (!isValidWcag2SrgbDomain(color))
        return false;

    value = wcag2RelativeLuminance(color);
    return true;
}

std::uint32_t nextRandom(std::uint32_t& state) noexcept
{
    state =
        state * 1664525U +
        1013904223U;

    return state;
}

template <ColorScalar T>
T randomUnit(std::uint32_t& state) noexcept
{
    const std::uint32_t bits =
        nextRandom(state) & 0x00FF'FFFFU;

    return
        static_cast<T>(bits) /
        static_cast<T>(0x00FF'FFFFU);
}

constexpr std::size_t sampleCount = 8192;
constexpr std::size_t repetitions = 1000;

template <typename F>
double benchmarkNsPerOperation(
    std::size_t operations,
    F&& work)
{
    const auto start =
        std::chrono::steady_clock::now();

    work();

    const auto finish =
        std::chrono::steady_clock::now();

    const auto nanoseconds =
        std::chrono::duration<double, std::nano>(
            finish - start).count();

    return
        nanoseconds /
        static_cast<double>(operations);
}

template <ColorScalar T>
void runBenchmark(std::string_view scalarName)
{
    std::array<SRgb<T>, sampleCount> encoded{};
    std::array<LinearSRgb<T>, sampleCount> linear{};

    std::uint32_t state = 0xC01D'0009U;

    for (std::size_t i = 0; i < sampleCount; ++i)
    {
        encoded[i] = SRgb<T>{
            randomUnit<T>(state),
            randomUnit<T>(state),
            randomUnit<T>(state)
        };

        linear[i] = toLinear(encoded[i]);
    }

    T checksum = T(0);

    const double linearUncheckedNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                    for (const auto c : linear)
                        checksum += wcag2RelativeLuminance(c);
            });

    const double linearCheckedNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                {
                    for (const auto c : linear)
                    {
                        const auto result =
                            checkedWcag2RelativeLuminance(c);

                        checksum += result.value;
                    }
                }
            });

    const double encodedUncheckedNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                    for (const auto c : encoded)
                        checksum += wcag2RelativeLuminance(c);
            });

    const double linearTryNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                {
                    for (const auto c : linear)
                    {
                        T value = T(0);

                        if (tryWcag2RelativeLuminance(c, value))
                            checksum += value;
                    }
                }
            });

    const double linearNanCheckedNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                    for (const auto c : linear)
                        checksum +=
                            nanCheckedWcag2RelativeLuminance(c);
            });

    const double encodedCheckedNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                {
                    for (const auto c : encoded)
                    {
                        const auto result =
                            checkedWcag2RelativeLuminance(c);

                        checksum += result.value;
                    }
                }
            });

    const double encodedTryNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                {
                    for (const auto c : encoded)
                    {
                        T value = T(0);

                        if (tryWcag2RelativeLuminance(c, value))
                            checksum += value;
                    }
                }
            });

    const double contrastCheckedNs =
        benchmarkNsPerOperation(
            (sampleCount - 1) * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                {
                    for (std::size_t i = 0; i < sampleCount - 1; ++i)
                    {
                        const auto result =
                            checkedWcag2ContrastRatio(
                                encoded[i],
                                encoded[i + 1]);

                        checksum += result.value;
                    }
                }
            });

    const double linearCompactNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                {
                    for (const auto c : linear)
                    {
                        const auto result =
                            compactCheckedWcag2RelativeLuminance(c);

                        if (result.valid())
                            checksum += result.value;
                    }
                }
            });

    const double encodedCompactNs =
        benchmarkNsPerOperation(
            sampleCount * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                {
                    for (const auto c : encoded)
                    {
                        const auto result =
                            compactCheckedWcag2RelativeLuminance(c);

                        if (result.valid())
                            checksum += result.value;
                    }
                }
            });

    const double contrastCompactNs =
        benchmarkNsPerOperation(
            (sampleCount - 1) * repetitions,
            [&] {
                for (std::size_t r = 0; r < repetitions; ++r)
                {
                    for (std::size_t i = 0; i < sampleCount - 1; ++i)
                    {
                        const auto result =
                            compactCheckedWcag2ContrastRatio(
                                encoded[i],
                                encoded[i + 1]);

                        if (result.valid())
                            checksum += result.value;
                    }
                }
            });

    std::cout
        << scalarName << ": linear unchecked = "
        << linearUncheckedNs << " ns\n"
        << scalarName << ": linear checked   = "
        << linearCheckedNs << " ns\n"
        << scalarName << ": linear try       = "
        << linearTryNs << " ns\n"
        << scalarName << ": linear NaN-check = "
        << linearNanCheckedNs << " ns\n"
        << scalarName << ": encoded unchecked = "
        << encodedUncheckedNs << " ns\n"
        << scalarName << ": encoded checked   = "
        << encodedCheckedNs << " ns\n"
        << scalarName << ": encoded try       = "
        << encodedTryNs << " ns\n"
        << scalarName << ": contrast checked  = "
        << contrastCheckedNs << " ns\n"
        << scalarName << ": linear compact   = "
        << linearCompactNs << " ns\n"
        << scalarName << ": encoded compact  = "
        << encodedCompactNs << " ns\n"
        << scalarName << ": contrast compact = "
        << contrastCompactNs << " ns\n"
        << scalarName << ": checked sizeof   = "
        << sizeof(Wcag2Measurement<T>) << "\n"
        << scalarName << ": compact sizeof   = "
        << sizeof(CompactWcag2Measurement<T>) << "\n"
        << scalarName << ": checksum = "
        << std::setprecision(17)
        << checksum << "\n";
}

int main()
{
    std::cout
        << "=== color-d R0.9 equivalent C++ luminance benchmark ===\n";

#if defined(__clang__)
    std::cout
        << "compiler: clang "
        << __clang_major__ << "."
        << __clang_minor__ << "."
        << __clang_patchlevel__ << "\n";
#elif defined(__GNUC__)
    std::cout
        << "compiler: gcc "
        << __GNUC__ << "."
        << __GNUC_MINOR__ << "."
        << __GNUC_PATCHLEVEL__ << "\n";
#endif

    runBenchmark<double>("double");
    runBenchmark<float>("float");
}
