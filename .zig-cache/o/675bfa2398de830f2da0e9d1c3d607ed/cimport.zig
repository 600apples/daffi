const __root = @This();
pub const __builtin = @import("std").zig.c_translation.builtins;
pub const __helpers = @import("std").zig.c_translation.helpers;
pub const __u_char = u8;
pub const __u_short = c_ushort;
pub const __u_int = c_uint;
pub const __u_long = c_ulong;
pub const __int8_t = i8;
pub const __uint8_t = u8;
pub const __int16_t = c_short;
pub const __uint16_t = c_ushort;
pub const __int32_t = c_int;
pub const __uint32_t = c_uint;
pub const __int64_t = c_long;
pub const __uint64_t = c_ulong;
pub const __int_least8_t = __int8_t;
pub const __uint_least8_t = __uint8_t;
pub const __int_least16_t = __int16_t;
pub const __uint_least16_t = __uint16_t;
pub const __int_least32_t = __int32_t;
pub const __uint_least32_t = __uint32_t;
pub const __int_least64_t = __int64_t;
pub const __uint_least64_t = __uint64_t;
pub const __quad_t = c_long;
pub const __u_quad_t = c_ulong;
pub const __intmax_t = c_long;
pub const __uintmax_t = c_ulong;
pub const __dev_t = c_ulong;
pub const __uid_t = c_uint;
pub const __gid_t = c_uint;
pub const __ino_t = c_ulong;
pub const __ino64_t = c_ulong;
pub const __mode_t = c_uint;
pub const __nlink_t = c_ulong;
pub const __off_t = c_long;
pub const __off64_t = c_long;
pub const __pid_t = c_int;
pub const __fsid_t = extern struct {
    __val: [2]c_int = @import("std").mem.zeroes([2]c_int),
};
pub const __clock_t = c_long;
pub const __rlim_t = c_ulong;
pub const __rlim64_t = c_ulong;
pub const __id_t = c_uint;
pub const __time_t = c_long;
pub const __useconds_t = c_uint;
pub const __suseconds_t = c_long;
pub const __suseconds64_t = c_long;
pub const __daddr_t = c_int;
pub const __key_t = c_int;
pub const __clockid_t = c_int;
pub const __timer_t = ?*anyopaque;
pub const __blksize_t = c_long;
pub const __blkcnt_t = c_long;
pub const __blkcnt64_t = c_long;
pub const __fsblkcnt_t = c_ulong;
pub const __fsblkcnt64_t = c_ulong;
pub const __fsfilcnt_t = c_ulong;
pub const __fsfilcnt64_t = c_ulong;
pub const __fsword_t = c_long;
pub const __ssize_t = c_long;
pub const __syscall_slong_t = c_long;
pub const __syscall_ulong_t = c_ulong;
pub const __loff_t = __off64_t;
pub const __caddr_t = [*c]u8;
pub const __intptr_t = c_long;
pub const __socklen_t = c_uint;
pub const __sig_atomic_t = c_int;
pub const int_least8_t = __int_least8_t;
pub const int_least16_t = __int_least16_t;
pub const int_least32_t = __int_least32_t;
pub const int_least64_t = __int_least64_t;
pub const uint_least8_t = __uint_least8_t;
pub const uint_least16_t = __uint_least16_t;
pub const uint_least32_t = __uint_least32_t;
pub const uint_least64_t = __uint_least64_t;
pub const int_fast8_t = i8;
pub const int_fast16_t = c_long;
pub const int_fast32_t = c_long;
pub const int_fast64_t = c_long;
pub const uint_fast8_t = u8;
pub const uint_fast16_t = c_ulong;
pub const uint_fast32_t = c_ulong;
pub const uint_fast64_t = c_ulong;
pub const intmax_t = __intmax_t;
pub const uintmax_t = __uintmax_t;
pub const __gwchar_t = c_int;
pub const imaxdiv_t = extern struct {
    quot: c_long = 0,
    rem: c_long = 0,
};
pub extern fn imaxabs(__n: intmax_t) intmax_t;
pub extern fn imaxdiv(__numer: intmax_t, __denom: intmax_t) imaxdiv_t;
pub extern fn strtoimax(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) intmax_t;
pub extern fn strtoumax(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) uintmax_t;
pub extern fn wcstoimax(noalias __nptr: [*c]const __gwchar_t, noalias __endptr: [*c][*c]__gwchar_t, __base: c_int) intmax_t;
pub extern fn wcstoumax(noalias __nptr: [*c]const __gwchar_t, noalias __endptr: [*c][*c]__gwchar_t, __base: c_int) uintmax_t;
pub extern fn __sysconf(__name: c_int) c_long;
pub const float_t = f32;
pub const double_t = f64;
pub const FP_INT_UPWARD: c_int = 0;
pub const FP_INT_DOWNWARD: c_int = 1;
pub const FP_INT_TOWARDZERO: c_int = 2;
pub const FP_INT_TONEARESTFROMZERO: c_int = 3;
pub const FP_INT_TONEAREST: c_int = 4;
const enum_unnamed_1 = c_uint;
pub extern fn __fpclassify(__value: f64) c_int;
pub extern fn __signbit(__value: f64) c_int;
pub extern fn __isinf(__value: f64) c_int;
pub extern fn __finite(__value: f64) c_int;
pub extern fn __isnan(__value: f64) c_int;
pub extern fn __iseqsig(__x: f64, __y: f64) c_int;
pub extern fn __issignaling(__value: f64) c_int;
pub extern fn acos(__x: f64) f64;
pub extern fn __acos(__x: f64) f64;
pub extern fn asin(__x: f64) f64;
pub extern fn __asin(__x: f64) f64;
pub extern fn atan(__x: f64) f64;
pub extern fn __atan(__x: f64) f64;
pub extern fn atan2(__y: f64, __x: f64) f64;
pub extern fn __atan2(__y: f64, __x: f64) f64;
pub extern fn cos(__x: f64) f64;
pub extern fn __cos(__x: f64) f64;
pub extern fn sin(__x: f64) f64;
pub extern fn __sin(__x: f64) f64;
pub extern fn tan(__x: f64) f64;
pub extern fn __tan(__x: f64) f64;
pub extern fn cosh(__x: f64) f64;
pub extern fn __cosh(__x: f64) f64;
pub extern fn sinh(__x: f64) f64;
pub extern fn __sinh(__x: f64) f64;
pub extern fn tanh(__x: f64) f64;
pub extern fn __tanh(__x: f64) f64;
pub extern fn sincos(__x: f64, __sinx: [*c]f64, __cosx: [*c]f64) void;
pub extern fn __sincos(__x: f64, __sinx: [*c]f64, __cosx: [*c]f64) void;
pub extern fn acosh(__x: f64) f64;
pub extern fn __acosh(__x: f64) f64;
pub extern fn asinh(__x: f64) f64;
pub extern fn __asinh(__x: f64) f64;
pub extern fn atanh(__x: f64) f64;
pub extern fn __atanh(__x: f64) f64;
pub extern fn exp(__x: f64) f64;
pub extern fn __exp(__x: f64) f64;
pub extern fn frexp(__x: f64, __exponent: [*c]c_int) f64;
pub extern fn __frexp(__x: f64, __exponent: [*c]c_int) f64;
pub extern fn ldexp(__x: f64, __exponent: c_int) f64;
pub extern fn __ldexp(__x: f64, __exponent: c_int) f64;
pub extern fn log(__x: f64) f64;
pub extern fn __log(__x: f64) f64;
pub extern fn log10(__x: f64) f64;
pub extern fn __log10(__x: f64) f64;
pub extern fn modf(__x: f64, __iptr: [*c]f64) f64;
pub extern fn __modf(__x: f64, __iptr: [*c]f64) f64;
pub extern fn exp10(__x: f64) f64;
pub extern fn __exp10(__x: f64) f64;
pub extern fn expm1(__x: f64) f64;
pub extern fn __expm1(__x: f64) f64;
pub extern fn log1p(__x: f64) f64;
pub extern fn __log1p(__x: f64) f64;
pub extern fn logb(__x: f64) f64;
pub extern fn __logb(__x: f64) f64;
pub extern fn exp2(__x: f64) f64;
pub extern fn __exp2(__x: f64) f64;
pub extern fn log2(__x: f64) f64;
pub extern fn __log2(__x: f64) f64;
pub extern fn pow(__x: f64, __y: f64) f64;
pub extern fn __pow(__x: f64, __y: f64) f64;
pub extern fn sqrt(__x: f64) f64;
pub extern fn __sqrt(__x: f64) f64;
pub extern fn hypot(__x: f64, __y: f64) f64;
pub extern fn __hypot(__x: f64, __y: f64) f64;
pub extern fn cbrt(__x: f64) f64;
pub extern fn __cbrt(__x: f64) f64;
pub extern fn ceil(__x: f64) f64;
pub extern fn __ceil(__x: f64) f64;
pub extern fn fabs(__x: f64) f64;
pub extern fn __fabs(__x: f64) f64;
pub extern fn floor(__x: f64) f64;
pub extern fn __floor(__x: f64) f64;
pub extern fn fmod(__x: f64, __y: f64) f64;
pub extern fn __fmod(__x: f64, __y: f64) f64;
pub extern fn isinf(__value: f64) c_int;
pub extern fn finite(__value: f64) c_int;
pub extern fn drem(__x: f64, __y: f64) f64;
pub extern fn __drem(__x: f64, __y: f64) f64;
pub extern fn significand(__x: f64) f64;
pub extern fn __significand(__x: f64) f64;
pub extern fn copysign(__x: f64, __y: f64) f64;
pub extern fn __copysign(__x: f64, __y: f64) f64;
pub extern fn nan(__tagb: [*c]const u8) f64;
pub extern fn __nan(__tagb: [*c]const u8) f64;
pub extern fn isnan(__value: f64) c_int;
pub extern fn j0(f64) f64;
pub extern fn __j0(f64) f64;
pub extern fn j1(f64) f64;
pub extern fn __j1(f64) f64;
pub extern fn jn(c_int, f64) f64;
pub extern fn __jn(c_int, f64) f64;
pub extern fn y0(f64) f64;
pub extern fn __y0(f64) f64;
pub extern fn y1(f64) f64;
pub extern fn __y1(f64) f64;
pub extern fn yn(c_int, f64) f64;
pub extern fn __yn(c_int, f64) f64;
pub extern fn erf(f64) f64;
pub extern fn __erf(f64) f64;
pub extern fn erfc(f64) f64;
pub extern fn __erfc(f64) f64;
pub extern fn lgamma(f64) f64;
pub extern fn __lgamma(f64) f64;
pub extern fn tgamma(f64) f64;
pub extern fn __tgamma(f64) f64;
pub extern fn gamma(f64) f64;
pub extern fn __gamma(f64) f64;
pub extern fn lgamma_r(f64, __signgamp: [*c]c_int) f64;
pub extern fn __lgamma_r(f64, __signgamp: [*c]c_int) f64;
pub extern fn rint(__x: f64) f64;
pub extern fn __rint(__x: f64) f64;
pub extern fn nextafter(__x: f64, __y: f64) f64;
pub extern fn __nextafter(__x: f64, __y: f64) f64;
pub extern fn nexttoward(__x: f64, __y: c_longdouble) f64;
pub extern fn __nexttoward(__x: f64, __y: c_longdouble) f64;
pub extern fn nextdown(__x: f64) f64;
pub extern fn __nextdown(__x: f64) f64;
pub extern fn nextup(__x: f64) f64;
pub extern fn __nextup(__x: f64) f64;
pub extern fn remainder(__x: f64, __y: f64) f64;
pub extern fn __remainder(__x: f64, __y: f64) f64;
pub extern fn scalbn(__x: f64, __n: c_int) f64;
pub extern fn __scalbn(__x: f64, __n: c_int) f64;
pub extern fn ilogb(__x: f64) c_int;
pub extern fn __ilogb(__x: f64) c_int;
pub extern fn llogb(__x: f64) c_long;
pub extern fn __llogb(__x: f64) c_long;
pub extern fn scalbln(__x: f64, __n: c_long) f64;
pub extern fn __scalbln(__x: f64, __n: c_long) f64;
pub extern fn nearbyint(__x: f64) f64;
pub extern fn __nearbyint(__x: f64) f64;
pub extern fn round(__x: f64) f64;
pub extern fn __round(__x: f64) f64;
pub extern fn trunc(__x: f64) f64;
pub extern fn __trunc(__x: f64) f64;
pub extern fn remquo(__x: f64, __y: f64, __quo: [*c]c_int) f64;
pub extern fn __remquo(__x: f64, __y: f64, __quo: [*c]c_int) f64;
pub extern fn lrint(__x: f64) c_long;
pub extern fn __lrint(__x: f64) c_long;
pub extern fn llrint(__x: f64) c_longlong;
pub extern fn __llrint(__x: f64) c_longlong;
pub extern fn lround(__x: f64) c_long;
pub extern fn __lround(__x: f64) c_long;
pub extern fn llround(__x: f64) c_longlong;
pub extern fn __llround(__x: f64) c_longlong;
pub extern fn fdim(__x: f64, __y: f64) f64;
pub extern fn __fdim(__x: f64, __y: f64) f64;
pub extern fn fmax(__x: f64, __y: f64) f64;
pub extern fn __fmax(__x: f64, __y: f64) f64;
pub extern fn fmin(__x: f64, __y: f64) f64;
pub extern fn __fmin(__x: f64, __y: f64) f64;
pub extern fn fma(__x: f64, __y: f64, __z: f64) f64;
pub extern fn __fma(__x: f64, __y: f64, __z: f64) f64;
pub extern fn roundeven(__x: f64) f64;
pub extern fn __roundeven(__x: f64) f64;
pub extern fn fromfp(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfp(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfp(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfp(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn fromfpx(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpx(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpx(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpx(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn canonicalize(__cx: [*c]f64, __x: [*c]const f64) c_int;
pub extern fn fmaxmag(__x: f64, __y: f64) f64;
pub extern fn __fmaxmag(__x: f64, __y: f64) f64;
pub extern fn fminmag(__x: f64, __y: f64) f64;
pub extern fn __fminmag(__x: f64, __y: f64) f64;
pub extern fn fmaximum(__x: f64, __y: f64) f64;
pub extern fn __fmaximum(__x: f64, __y: f64) f64;
pub extern fn fminimum(__x: f64, __y: f64) f64;
pub extern fn __fminimum(__x: f64, __y: f64) f64;
pub extern fn fmaximum_num(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_num(__x: f64, __y: f64) f64;
pub extern fn fminimum_num(__x: f64, __y: f64) f64;
pub extern fn __fminimum_num(__x: f64, __y: f64) f64;
pub extern fn fmaximum_mag(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_mag(__x: f64, __y: f64) f64;
pub extern fn fminimum_mag(__x: f64, __y: f64) f64;
pub extern fn __fminimum_mag(__x: f64, __y: f64) f64;
pub extern fn fmaximum_mag_num(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_mag_num(__x: f64, __y: f64) f64;
pub extern fn fminimum_mag_num(__x: f64, __y: f64) f64;
pub extern fn __fminimum_mag_num(__x: f64, __y: f64) f64;
pub extern fn totalorder(__x: [*c]const f64, __y: [*c]const f64) c_int;
pub extern fn totalordermag(__x: [*c]const f64, __y: [*c]const f64) c_int;
pub extern fn getpayload(__x: [*c]const f64) f64;
pub extern fn __getpayload(__x: [*c]const f64) f64;
pub extern fn setpayload(__x: [*c]f64, __payload: f64) c_int;
pub extern fn setpayloadsig(__x: [*c]f64, __payload: f64) c_int;
pub extern fn scalb(__x: f64, __n: f64) f64;
pub extern fn __scalb(__x: f64, __n: f64) f64;
pub extern fn __fpclassifyf(__value: f32) c_int;
pub extern fn __signbitf(__value: f32) c_int;
pub extern fn __isinff(__value: f32) c_int;
pub extern fn __finitef(__value: f32) c_int;
pub extern fn __isnanf(__value: f32) c_int;
pub extern fn __iseqsigf(__x: f32, __y: f32) c_int;
pub extern fn __issignalingf(__value: f32) c_int;
pub extern fn acosf(__x: f32) f32;
pub extern fn __acosf(__x: f32) f32;
pub extern fn asinf(__x: f32) f32;
pub extern fn __asinf(__x: f32) f32;
pub extern fn atanf(__x: f32) f32;
pub extern fn __atanf(__x: f32) f32;
pub extern fn atan2f(__y: f32, __x: f32) f32;
pub extern fn __atan2f(__y: f32, __x: f32) f32;
pub extern fn cosf(__x: f32) f32;
pub extern fn __cosf(__x: f32) f32;
pub extern fn sinf(__x: f32) f32;
pub extern fn __sinf(__x: f32) f32;
pub extern fn tanf(__x: f32) f32;
pub extern fn __tanf(__x: f32) f32;
pub extern fn coshf(__x: f32) f32;
pub extern fn __coshf(__x: f32) f32;
pub extern fn sinhf(__x: f32) f32;
pub extern fn __sinhf(__x: f32) f32;
pub extern fn tanhf(__x: f32) f32;
pub extern fn __tanhf(__x: f32) f32;
pub extern fn sincosf(__x: f32, __sinx: [*c]f32, __cosx: [*c]f32) void;
pub extern fn __sincosf(__x: f32, __sinx: [*c]f32, __cosx: [*c]f32) void;
pub extern fn acoshf(__x: f32) f32;
pub extern fn __acoshf(__x: f32) f32;
pub extern fn asinhf(__x: f32) f32;
pub extern fn __asinhf(__x: f32) f32;
pub extern fn atanhf(__x: f32) f32;
pub extern fn __atanhf(__x: f32) f32;
pub extern fn expf(__x: f32) f32;
pub extern fn __expf(__x: f32) f32;
pub extern fn frexpf(__x: f32, __exponent: [*c]c_int) f32;
pub extern fn __frexpf(__x: f32, __exponent: [*c]c_int) f32;
pub extern fn ldexpf(__x: f32, __exponent: c_int) f32;
pub extern fn __ldexpf(__x: f32, __exponent: c_int) f32;
pub extern fn logf(__x: f32) f32;
pub extern fn __logf(__x: f32) f32;
pub extern fn log10f(__x: f32) f32;
pub extern fn __log10f(__x: f32) f32;
pub extern fn modff(__x: f32, __iptr: [*c]f32) f32;
pub extern fn __modff(__x: f32, __iptr: [*c]f32) f32;
pub extern fn exp10f(__x: f32) f32;
pub extern fn __exp10f(__x: f32) f32;
pub extern fn expm1f(__x: f32) f32;
pub extern fn __expm1f(__x: f32) f32;
pub extern fn log1pf(__x: f32) f32;
pub extern fn __log1pf(__x: f32) f32;
pub extern fn logbf(__x: f32) f32;
pub extern fn __logbf(__x: f32) f32;
pub extern fn exp2f(__x: f32) f32;
pub extern fn __exp2f(__x: f32) f32;
pub extern fn log2f(__x: f32) f32;
pub extern fn __log2f(__x: f32) f32;
pub extern fn powf(__x: f32, __y: f32) f32;
pub extern fn __powf(__x: f32, __y: f32) f32;
pub extern fn sqrtf(__x: f32) f32;
pub extern fn __sqrtf(__x: f32) f32;
pub extern fn hypotf(__x: f32, __y: f32) f32;
pub extern fn __hypotf(__x: f32, __y: f32) f32;
pub extern fn cbrtf(__x: f32) f32;
pub extern fn __cbrtf(__x: f32) f32;
pub extern fn ceilf(__x: f32) f32;
pub extern fn __ceilf(__x: f32) f32;
pub extern fn fabsf(__x: f32) f32;
pub extern fn __fabsf(__x: f32) f32;
pub extern fn floorf(__x: f32) f32;
pub extern fn __floorf(__x: f32) f32;
pub extern fn fmodf(__x: f32, __y: f32) f32;
pub extern fn __fmodf(__x: f32, __y: f32) f32;
pub extern fn isinff(__value: f32) c_int;
pub extern fn finitef(__value: f32) c_int;
pub extern fn dremf(__x: f32, __y: f32) f32;
pub extern fn __dremf(__x: f32, __y: f32) f32;
pub extern fn significandf(__x: f32) f32;
pub extern fn __significandf(__x: f32) f32;
pub extern fn copysignf(__x: f32, __y: f32) f32;
pub extern fn __copysignf(__x: f32, __y: f32) f32;
pub extern fn nanf(__tagb: [*c]const u8) f32;
pub extern fn __nanf(__tagb: [*c]const u8) f32;
pub extern fn isnanf(__value: f32) c_int;
pub extern fn j0f(f32) f32;
pub extern fn __j0f(f32) f32;
pub extern fn j1f(f32) f32;
pub extern fn __j1f(f32) f32;
pub extern fn jnf(c_int, f32) f32;
pub extern fn __jnf(c_int, f32) f32;
pub extern fn y0f(f32) f32;
pub extern fn __y0f(f32) f32;
pub extern fn y1f(f32) f32;
pub extern fn __y1f(f32) f32;
pub extern fn ynf(c_int, f32) f32;
pub extern fn __ynf(c_int, f32) f32;
pub extern fn erff(f32) f32;
pub extern fn __erff(f32) f32;
pub extern fn erfcf(f32) f32;
pub extern fn __erfcf(f32) f32;
pub extern fn lgammaf(f32) f32;
pub extern fn __lgammaf(f32) f32;
pub extern fn tgammaf(f32) f32;
pub extern fn __tgammaf(f32) f32;
pub extern fn gammaf(f32) f32;
pub extern fn __gammaf(f32) f32;
pub extern fn lgammaf_r(f32, __signgamp: [*c]c_int) f32;
pub extern fn __lgammaf_r(f32, __signgamp: [*c]c_int) f32;
pub extern fn rintf(__x: f32) f32;
pub extern fn __rintf(__x: f32) f32;
pub extern fn nextafterf(__x: f32, __y: f32) f32;
pub extern fn __nextafterf(__x: f32, __y: f32) f32;
pub extern fn nexttowardf(__x: f32, __y: c_longdouble) f32;
pub extern fn __nexttowardf(__x: f32, __y: c_longdouble) f32;
pub extern fn nextdownf(__x: f32) f32;
pub extern fn __nextdownf(__x: f32) f32;
pub extern fn nextupf(__x: f32) f32;
pub extern fn __nextupf(__x: f32) f32;
pub extern fn remainderf(__x: f32, __y: f32) f32;
pub extern fn __remainderf(__x: f32, __y: f32) f32;
pub extern fn scalbnf(__x: f32, __n: c_int) f32;
pub extern fn __scalbnf(__x: f32, __n: c_int) f32;
pub extern fn ilogbf(__x: f32) c_int;
pub extern fn __ilogbf(__x: f32) c_int;
pub extern fn llogbf(__x: f32) c_long;
pub extern fn __llogbf(__x: f32) c_long;
pub extern fn scalblnf(__x: f32, __n: c_long) f32;
pub extern fn __scalblnf(__x: f32, __n: c_long) f32;
pub extern fn nearbyintf(__x: f32) f32;
pub extern fn __nearbyintf(__x: f32) f32;
pub extern fn roundf(__x: f32) f32;
pub extern fn __roundf(__x: f32) f32;
pub extern fn truncf(__x: f32) f32;
pub extern fn __truncf(__x: f32) f32;
pub extern fn remquof(__x: f32, __y: f32, __quo: [*c]c_int) f32;
pub extern fn __remquof(__x: f32, __y: f32, __quo: [*c]c_int) f32;
pub extern fn lrintf(__x: f32) c_long;
pub extern fn __lrintf(__x: f32) c_long;
pub extern fn llrintf(__x: f32) c_longlong;
pub extern fn __llrintf(__x: f32) c_longlong;
pub extern fn lroundf(__x: f32) c_long;
pub extern fn __lroundf(__x: f32) c_long;
pub extern fn llroundf(__x: f32) c_longlong;
pub extern fn __llroundf(__x: f32) c_longlong;
pub extern fn fdimf(__x: f32, __y: f32) f32;
pub extern fn __fdimf(__x: f32, __y: f32) f32;
pub extern fn fmaxf(__x: f32, __y: f32) f32;
pub extern fn __fmaxf(__x: f32, __y: f32) f32;
pub extern fn fminf(__x: f32, __y: f32) f32;
pub extern fn __fminf(__x: f32, __y: f32) f32;
pub extern fn fmaf(__x: f32, __y: f32, __z: f32) f32;
pub extern fn __fmaf(__x: f32, __y: f32, __z: f32) f32;
pub extern fn roundevenf(__x: f32) f32;
pub extern fn __roundevenf(__x: f32) f32;
pub extern fn fromfpf(__x: f32, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpf(__x: f32, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpf(__x: f32, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpf(__x: f32, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn fromfpxf(__x: f32, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpxf(__x: f32, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpxf(__x: f32, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpxf(__x: f32, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn canonicalizef(__cx: [*c]f32, __x: [*c]const f32) c_int;
pub extern fn fmaxmagf(__x: f32, __y: f32) f32;
pub extern fn __fmaxmagf(__x: f32, __y: f32) f32;
pub extern fn fminmagf(__x: f32, __y: f32) f32;
pub extern fn __fminmagf(__x: f32, __y: f32) f32;
pub extern fn fmaximumf(__x: f32, __y: f32) f32;
pub extern fn __fmaximumf(__x: f32, __y: f32) f32;
pub extern fn fminimumf(__x: f32, __y: f32) f32;
pub extern fn __fminimumf(__x: f32, __y: f32) f32;
pub extern fn fmaximum_numf(__x: f32, __y: f32) f32;
pub extern fn __fmaximum_numf(__x: f32, __y: f32) f32;
pub extern fn fminimum_numf(__x: f32, __y: f32) f32;
pub extern fn __fminimum_numf(__x: f32, __y: f32) f32;
pub extern fn fmaximum_magf(__x: f32, __y: f32) f32;
pub extern fn __fmaximum_magf(__x: f32, __y: f32) f32;
pub extern fn fminimum_magf(__x: f32, __y: f32) f32;
pub extern fn __fminimum_magf(__x: f32, __y: f32) f32;
pub extern fn fmaximum_mag_numf(__x: f32, __y: f32) f32;
pub extern fn __fmaximum_mag_numf(__x: f32, __y: f32) f32;
pub extern fn fminimum_mag_numf(__x: f32, __y: f32) f32;
pub extern fn __fminimum_mag_numf(__x: f32, __y: f32) f32;
pub extern fn totalorderf(__x: [*c]const f32, __y: [*c]const f32) c_int;
pub extern fn totalordermagf(__x: [*c]const f32, __y: [*c]const f32) c_int;
pub extern fn getpayloadf(__x: [*c]const f32) f32;
pub extern fn __getpayloadf(__x: [*c]const f32) f32;
pub extern fn setpayloadf(__x: [*c]f32, __payload: f32) c_int;
pub extern fn setpayloadsigf(__x: [*c]f32, __payload: f32) c_int;
pub extern fn scalbf(__x: f32, __n: f32) f32;
pub extern fn __scalbf(__x: f32, __n: f32) f32;
pub extern fn __fpclassifyl(__value: c_longdouble) c_int;
pub extern fn __signbitl(__value: c_longdouble) c_int;
pub extern fn __isinfl(__value: c_longdouble) c_int;
pub extern fn __finitel(__value: c_longdouble) c_int;
pub extern fn __isnanl(__value: c_longdouble) c_int;
pub extern fn __iseqsigl(__x: c_longdouble, __y: c_longdouble) c_int;
pub extern fn __issignalingl(__value: c_longdouble) c_int;
pub extern fn acosl(__x: c_longdouble) c_longdouble;
pub extern fn __acosl(__x: c_longdouble) c_longdouble;
pub extern fn asinl(__x: c_longdouble) c_longdouble;
pub extern fn __asinl(__x: c_longdouble) c_longdouble;
pub extern fn atanl(__x: c_longdouble) c_longdouble;
pub extern fn __atanl(__x: c_longdouble) c_longdouble;
pub extern fn atan2l(__y: c_longdouble, __x: c_longdouble) c_longdouble;
pub extern fn __atan2l(__y: c_longdouble, __x: c_longdouble) c_longdouble;
pub extern fn cosl(__x: c_longdouble) c_longdouble;
pub extern fn __cosl(__x: c_longdouble) c_longdouble;
pub extern fn sinl(__x: c_longdouble) c_longdouble;
pub extern fn __sinl(__x: c_longdouble) c_longdouble;
pub extern fn tanl(__x: c_longdouble) c_longdouble;
pub extern fn __tanl(__x: c_longdouble) c_longdouble;
pub extern fn coshl(__x: c_longdouble) c_longdouble;
pub extern fn __coshl(__x: c_longdouble) c_longdouble;
pub extern fn sinhl(__x: c_longdouble) c_longdouble;
pub extern fn __sinhl(__x: c_longdouble) c_longdouble;
pub extern fn tanhl(__x: c_longdouble) c_longdouble;
pub extern fn __tanhl(__x: c_longdouble) c_longdouble;
pub extern fn sincosl(__x: c_longdouble, __sinx: [*c]c_longdouble, __cosx: [*c]c_longdouble) void;
pub extern fn __sincosl(__x: c_longdouble, __sinx: [*c]c_longdouble, __cosx: [*c]c_longdouble) void;
pub extern fn acoshl(__x: c_longdouble) c_longdouble;
pub extern fn __acoshl(__x: c_longdouble) c_longdouble;
pub extern fn asinhl(__x: c_longdouble) c_longdouble;
pub extern fn __asinhl(__x: c_longdouble) c_longdouble;
pub extern fn atanhl(__x: c_longdouble) c_longdouble;
pub extern fn __atanhl(__x: c_longdouble) c_longdouble;
pub extern fn expl(__x: c_longdouble) c_longdouble;
pub extern fn __expl(__x: c_longdouble) c_longdouble;
pub extern fn frexpl(__x: c_longdouble, __exponent: [*c]c_int) c_longdouble;
pub extern fn __frexpl(__x: c_longdouble, __exponent: [*c]c_int) c_longdouble;
pub extern fn ldexpl(__x: c_longdouble, __exponent: c_int) c_longdouble;
pub extern fn __ldexpl(__x: c_longdouble, __exponent: c_int) c_longdouble;
pub extern fn logl(__x: c_longdouble) c_longdouble;
pub extern fn __logl(__x: c_longdouble) c_longdouble;
pub extern fn log10l(__x: c_longdouble) c_longdouble;
pub extern fn __log10l(__x: c_longdouble) c_longdouble;
pub extern fn modfl(__x: c_longdouble, __iptr: [*c]c_longdouble) c_longdouble;
pub extern fn __modfl(__x: c_longdouble, __iptr: [*c]c_longdouble) c_longdouble;
pub extern fn exp10l(__x: c_longdouble) c_longdouble;
pub extern fn __exp10l(__x: c_longdouble) c_longdouble;
pub extern fn expm1l(__x: c_longdouble) c_longdouble;
pub extern fn __expm1l(__x: c_longdouble) c_longdouble;
pub extern fn log1pl(__x: c_longdouble) c_longdouble;
pub extern fn __log1pl(__x: c_longdouble) c_longdouble;
pub extern fn logbl(__x: c_longdouble) c_longdouble;
pub extern fn __logbl(__x: c_longdouble) c_longdouble;
pub extern fn exp2l(__x: c_longdouble) c_longdouble;
pub extern fn __exp2l(__x: c_longdouble) c_longdouble;
pub extern fn log2l(__x: c_longdouble) c_longdouble;
pub extern fn __log2l(__x: c_longdouble) c_longdouble;
pub extern fn powl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __powl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn sqrtl(__x: c_longdouble) c_longdouble;
pub extern fn __sqrtl(__x: c_longdouble) c_longdouble;
pub extern fn hypotl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __hypotl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn cbrtl(__x: c_longdouble) c_longdouble;
pub extern fn __cbrtl(__x: c_longdouble) c_longdouble;
pub extern fn ceill(__x: c_longdouble) c_longdouble;
pub extern fn __ceill(__x: c_longdouble) c_longdouble;
pub extern fn fabsl(__x: c_longdouble) c_longdouble;
pub extern fn __fabsl(__x: c_longdouble) c_longdouble;
pub extern fn floorl(__x: c_longdouble) c_longdouble;
pub extern fn __floorl(__x: c_longdouble) c_longdouble;
pub extern fn fmodl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmodl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn isinfl(__value: c_longdouble) c_int;
pub extern fn finitel(__value: c_longdouble) c_int;
pub extern fn dreml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __dreml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn significandl(__x: c_longdouble) c_longdouble;
pub extern fn __significandl(__x: c_longdouble) c_longdouble;
pub extern fn copysignl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __copysignl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn nanl(__tagb: [*c]const u8) c_longdouble;
pub extern fn __nanl(__tagb: [*c]const u8) c_longdouble;
pub extern fn isnanl(__value: c_longdouble) c_int;
pub extern fn j0l(c_longdouble) c_longdouble;
pub extern fn __j0l(c_longdouble) c_longdouble;
pub extern fn j1l(c_longdouble) c_longdouble;
pub extern fn __j1l(c_longdouble) c_longdouble;
pub extern fn jnl(c_int, c_longdouble) c_longdouble;
pub extern fn __jnl(c_int, c_longdouble) c_longdouble;
pub extern fn y0l(c_longdouble) c_longdouble;
pub extern fn __y0l(c_longdouble) c_longdouble;
pub extern fn y1l(c_longdouble) c_longdouble;
pub extern fn __y1l(c_longdouble) c_longdouble;
pub extern fn ynl(c_int, c_longdouble) c_longdouble;
pub extern fn __ynl(c_int, c_longdouble) c_longdouble;
pub extern fn erfl(c_longdouble) c_longdouble;
pub extern fn __erfl(c_longdouble) c_longdouble;
pub extern fn erfcl(c_longdouble) c_longdouble;
pub extern fn __erfcl(c_longdouble) c_longdouble;
pub extern fn lgammal(c_longdouble) c_longdouble;
pub extern fn __lgammal(c_longdouble) c_longdouble;
pub extern fn tgammal(c_longdouble) c_longdouble;
pub extern fn __tgammal(c_longdouble) c_longdouble;
pub extern fn gammal(c_longdouble) c_longdouble;
pub extern fn __gammal(c_longdouble) c_longdouble;
pub extern fn lgammal_r(c_longdouble, __signgamp: [*c]c_int) c_longdouble;
pub extern fn __lgammal_r(c_longdouble, __signgamp: [*c]c_int) c_longdouble;
pub extern fn rintl(__x: c_longdouble) c_longdouble;
pub extern fn __rintl(__x: c_longdouble) c_longdouble;
pub extern fn nextafterl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __nextafterl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn nexttowardl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __nexttowardl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn nextdownl(__x: c_longdouble) c_longdouble;
pub extern fn __nextdownl(__x: c_longdouble) c_longdouble;
pub extern fn nextupl(__x: c_longdouble) c_longdouble;
pub extern fn __nextupl(__x: c_longdouble) c_longdouble;
pub extern fn remainderl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __remainderl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn scalbnl(__x: c_longdouble, __n: c_int) c_longdouble;
pub extern fn __scalbnl(__x: c_longdouble, __n: c_int) c_longdouble;
pub extern fn ilogbl(__x: c_longdouble) c_int;
pub extern fn __ilogbl(__x: c_longdouble) c_int;
pub extern fn llogbl(__x: c_longdouble) c_long;
pub extern fn __llogbl(__x: c_longdouble) c_long;
pub extern fn scalblnl(__x: c_longdouble, __n: c_long) c_longdouble;
pub extern fn __scalblnl(__x: c_longdouble, __n: c_long) c_longdouble;
pub extern fn nearbyintl(__x: c_longdouble) c_longdouble;
pub extern fn __nearbyintl(__x: c_longdouble) c_longdouble;
pub extern fn roundl(__x: c_longdouble) c_longdouble;
pub extern fn __roundl(__x: c_longdouble) c_longdouble;
pub extern fn truncl(__x: c_longdouble) c_longdouble;
pub extern fn __truncl(__x: c_longdouble) c_longdouble;
pub extern fn remquol(__x: c_longdouble, __y: c_longdouble, __quo: [*c]c_int) c_longdouble;
pub extern fn __remquol(__x: c_longdouble, __y: c_longdouble, __quo: [*c]c_int) c_longdouble;
pub extern fn lrintl(__x: c_longdouble) c_long;
pub extern fn __lrintl(__x: c_longdouble) c_long;
pub extern fn llrintl(__x: c_longdouble) c_longlong;
pub extern fn __llrintl(__x: c_longdouble) c_longlong;
pub extern fn lroundl(__x: c_longdouble) c_long;
pub extern fn __lroundl(__x: c_longdouble) c_long;
pub extern fn llroundl(__x: c_longdouble) c_longlong;
pub extern fn __llroundl(__x: c_longdouble) c_longlong;
pub extern fn fdiml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fdiml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaxl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaxl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmal(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) c_longdouble;
pub extern fn __fmal(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) c_longdouble;
pub extern fn roundevenl(__x: c_longdouble) c_longdouble;
pub extern fn __roundevenl(__x: c_longdouble) c_longdouble;
pub extern fn fromfpl(__x: c_longdouble, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpl(__x: c_longdouble, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpl(__x: c_longdouble, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpl(__x: c_longdouble, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn fromfpxl(__x: c_longdouble, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpxl(__x: c_longdouble, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpxl(__x: c_longdouble, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpxl(__x: c_longdouble, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn canonicalizel(__cx: [*c]c_longdouble, __x: [*c]const c_longdouble) c_int;
pub extern fn fmaxmagl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaxmagl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminmagl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminmagl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaximuml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaximuml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminimuml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminimuml(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaximum_numl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaximum_numl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminimum_numl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminimum_numl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaximum_magl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaximum_magl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminimum_magl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminimum_magl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaximum_mag_numl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaximum_mag_numl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminimum_mag_numl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminimum_mag_numl(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn totalorderl(__x: [*c]const c_longdouble, __y: [*c]const c_longdouble) c_int;
pub extern fn totalordermagl(__x: [*c]const c_longdouble, __y: [*c]const c_longdouble) c_int;
pub extern fn getpayloadl(__x: [*c]const c_longdouble) c_longdouble;
pub extern fn __getpayloadl(__x: [*c]const c_longdouble) c_longdouble;
pub extern fn setpayloadl(__x: [*c]c_longdouble, __payload: c_longdouble) c_int;
pub extern fn setpayloadsigl(__x: [*c]c_longdouble, __payload: c_longdouble) c_int;
pub extern fn scalbl(__x: c_longdouble, __n: c_longdouble) c_longdouble;
pub extern fn __scalbl(__x: c_longdouble, __n: c_longdouble) c_longdouble;
pub extern fn acosf32(__x: f32) f32;
pub extern fn __acosf32(__x: f32) f32;
pub extern fn asinf32(__x: f32) f32;
pub extern fn __asinf32(__x: f32) f32;
pub extern fn atanf32(__x: f32) f32;
pub extern fn __atanf32(__x: f32) f32;
pub extern fn atan2f32(__y: f32, __x: f32) f32;
pub extern fn __atan2f32(__y: f32, __x: f32) f32;
pub extern fn cosf32(__x: f32) f32;
pub extern fn __cosf32(__x: f32) f32;
pub extern fn sinf32(__x: f32) f32;
pub extern fn __sinf32(__x: f32) f32;
pub extern fn tanf32(__x: f32) f32;
pub extern fn __tanf32(__x: f32) f32;
pub extern fn coshf32(__x: f32) f32;
pub extern fn __coshf32(__x: f32) f32;
pub extern fn sinhf32(__x: f32) f32;
pub extern fn __sinhf32(__x: f32) f32;
pub extern fn tanhf32(__x: f32) f32;
pub extern fn __tanhf32(__x: f32) f32;
pub extern fn sincosf32(__x: f32, __sinx: [*c]f32, __cosx: [*c]f32) void;
pub extern fn __sincosf32(__x: f32, __sinx: [*c]f32, __cosx: [*c]f32) void;
pub extern fn acoshf32(__x: f32) f32;
pub extern fn __acoshf32(__x: f32) f32;
pub extern fn asinhf32(__x: f32) f32;
pub extern fn __asinhf32(__x: f32) f32;
pub extern fn atanhf32(__x: f32) f32;
pub extern fn __atanhf32(__x: f32) f32;
pub extern fn expf32(__x: f32) f32;
pub extern fn __expf32(__x: f32) f32;
pub extern fn frexpf32(__x: f32, __exponent: [*c]c_int) f32;
pub extern fn __frexpf32(__x: f32, __exponent: [*c]c_int) f32;
pub extern fn ldexpf32(__x: f32, __exponent: c_int) f32;
pub extern fn __ldexpf32(__x: f32, __exponent: c_int) f32;
pub extern fn logf32(__x: f32) f32;
pub extern fn __logf32(__x: f32) f32;
pub extern fn log10f32(__x: f32) f32;
pub extern fn __log10f32(__x: f32) f32;
pub extern fn modff32(__x: f32, __iptr: [*c]f32) f32;
pub extern fn __modff32(__x: f32, __iptr: [*c]f32) f32;
pub extern fn exp10f32(__x: f32) f32;
pub extern fn __exp10f32(__x: f32) f32;
pub extern fn expm1f32(__x: f32) f32;
pub extern fn __expm1f32(__x: f32) f32;
pub extern fn log1pf32(__x: f32) f32;
pub extern fn __log1pf32(__x: f32) f32;
pub extern fn logbf32(__x: f32) f32;
pub extern fn __logbf32(__x: f32) f32;
pub extern fn exp2f32(__x: f32) f32;
pub extern fn __exp2f32(__x: f32) f32;
pub extern fn log2f32(__x: f32) f32;
pub extern fn __log2f32(__x: f32) f32;
pub extern fn powf32(__x: f32, __y: f32) f32;
pub extern fn __powf32(__x: f32, __y: f32) f32;
pub extern fn sqrtf32(__x: f32) f32;
pub extern fn __sqrtf32(__x: f32) f32;
pub extern fn hypotf32(__x: f32, __y: f32) f32;
pub extern fn __hypotf32(__x: f32, __y: f32) f32;
pub extern fn cbrtf32(__x: f32) f32;
pub extern fn __cbrtf32(__x: f32) f32;
pub extern fn ceilf32(__x: f32) f32;
pub extern fn __ceilf32(__x: f32) f32;
pub extern fn fabsf32(__x: f32) f32;
pub extern fn __fabsf32(__x: f32) f32;
pub extern fn floorf32(__x: f32) f32;
pub extern fn __floorf32(__x: f32) f32;
pub extern fn fmodf32(__x: f32, __y: f32) f32;
pub extern fn __fmodf32(__x: f32, __y: f32) f32;
pub extern fn copysignf32(__x: f32, __y: f32) f32;
pub extern fn __copysignf32(__x: f32, __y: f32) f32;
pub extern fn nanf32(__tagb: [*c]const u8) f32;
pub extern fn __nanf32(__tagb: [*c]const u8) f32;
pub extern fn j0f32(f32) f32;
pub extern fn __j0f32(f32) f32;
pub extern fn j1f32(f32) f32;
pub extern fn __j1f32(f32) f32;
pub extern fn jnf32(c_int, f32) f32;
pub extern fn __jnf32(c_int, f32) f32;
pub extern fn y0f32(f32) f32;
pub extern fn __y0f32(f32) f32;
pub extern fn y1f32(f32) f32;
pub extern fn __y1f32(f32) f32;
pub extern fn ynf32(c_int, f32) f32;
pub extern fn __ynf32(c_int, f32) f32;
pub extern fn erff32(f32) f32;
pub extern fn __erff32(f32) f32;
pub extern fn erfcf32(f32) f32;
pub extern fn __erfcf32(f32) f32;
pub extern fn lgammaf32(f32) f32;
pub extern fn __lgammaf32(f32) f32;
pub extern fn tgammaf32(f32) f32;
pub extern fn __tgammaf32(f32) f32;
pub extern fn lgammaf32_r(f32, __signgamp: [*c]c_int) f32;
pub extern fn __lgammaf32_r(f32, __signgamp: [*c]c_int) f32;
pub extern fn rintf32(__x: f32) f32;
pub extern fn __rintf32(__x: f32) f32;
pub extern fn nextafterf32(__x: f32, __y: f32) f32;
pub extern fn __nextafterf32(__x: f32, __y: f32) f32;
pub extern fn nextdownf32(__x: f32) f32;
pub extern fn __nextdownf32(__x: f32) f32;
pub extern fn nextupf32(__x: f32) f32;
pub extern fn __nextupf32(__x: f32) f32;
pub extern fn remainderf32(__x: f32, __y: f32) f32;
pub extern fn __remainderf32(__x: f32, __y: f32) f32;
pub extern fn scalbnf32(__x: f32, __n: c_int) f32;
pub extern fn __scalbnf32(__x: f32, __n: c_int) f32;
pub extern fn ilogbf32(__x: f32) c_int;
pub extern fn __ilogbf32(__x: f32) c_int;
pub extern fn llogbf32(__x: f32) c_long;
pub extern fn __llogbf32(__x: f32) c_long;
pub extern fn scalblnf32(__x: f32, __n: c_long) f32;
pub extern fn __scalblnf32(__x: f32, __n: c_long) f32;
pub extern fn nearbyintf32(__x: f32) f32;
pub extern fn __nearbyintf32(__x: f32) f32;
pub extern fn roundf32(__x: f32) f32;
pub extern fn __roundf32(__x: f32) f32;
pub extern fn truncf32(__x: f32) f32;
pub extern fn __truncf32(__x: f32) f32;
pub extern fn remquof32(__x: f32, __y: f32, __quo: [*c]c_int) f32;
pub extern fn __remquof32(__x: f32, __y: f32, __quo: [*c]c_int) f32;
pub extern fn lrintf32(__x: f32) c_long;
pub extern fn __lrintf32(__x: f32) c_long;
pub extern fn llrintf32(__x: f32) c_longlong;
pub extern fn __llrintf32(__x: f32) c_longlong;
pub extern fn lroundf32(__x: f32) c_long;
pub extern fn __lroundf32(__x: f32) c_long;
pub extern fn llroundf32(__x: f32) c_longlong;
pub extern fn __llroundf32(__x: f32) c_longlong;
pub extern fn fdimf32(__x: f32, __y: f32) f32;
pub extern fn __fdimf32(__x: f32, __y: f32) f32;
pub extern fn fmaxf32(__x: f32, __y: f32) f32;
pub extern fn __fmaxf32(__x: f32, __y: f32) f32;
pub extern fn fminf32(__x: f32, __y: f32) f32;
pub extern fn __fminf32(__x: f32, __y: f32) f32;
pub extern fn fmaf32(__x: f32, __y: f32, __z: f32) f32;
pub extern fn __fmaf32(__x: f32, __y: f32, __z: f32) f32;
pub extern fn roundevenf32(__x: f32) f32;
pub extern fn __roundevenf32(__x: f32) f32;
pub extern fn fromfpf32(__x: f32, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpf32(__x: f32, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpf32(__x: f32, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpf32(__x: f32, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn fromfpxf32(__x: f32, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpxf32(__x: f32, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpxf32(__x: f32, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpxf32(__x: f32, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn canonicalizef32(__cx: [*c]f32, __x: [*c]const f32) c_int;
pub extern fn fmaxmagf32(__x: f32, __y: f32) f32;
pub extern fn __fmaxmagf32(__x: f32, __y: f32) f32;
pub extern fn fminmagf32(__x: f32, __y: f32) f32;
pub extern fn __fminmagf32(__x: f32, __y: f32) f32;
pub extern fn fmaximumf32(__x: f32, __y: f32) f32;
pub extern fn __fmaximumf32(__x: f32, __y: f32) f32;
pub extern fn fminimumf32(__x: f32, __y: f32) f32;
pub extern fn __fminimumf32(__x: f32, __y: f32) f32;
pub extern fn fmaximum_numf32(__x: f32, __y: f32) f32;
pub extern fn __fmaximum_numf32(__x: f32, __y: f32) f32;
pub extern fn fminimum_numf32(__x: f32, __y: f32) f32;
pub extern fn __fminimum_numf32(__x: f32, __y: f32) f32;
pub extern fn fmaximum_magf32(__x: f32, __y: f32) f32;
pub extern fn __fmaximum_magf32(__x: f32, __y: f32) f32;
pub extern fn fminimum_magf32(__x: f32, __y: f32) f32;
pub extern fn __fminimum_magf32(__x: f32, __y: f32) f32;
pub extern fn fmaximum_mag_numf32(__x: f32, __y: f32) f32;
pub extern fn __fmaximum_mag_numf32(__x: f32, __y: f32) f32;
pub extern fn fminimum_mag_numf32(__x: f32, __y: f32) f32;
pub extern fn __fminimum_mag_numf32(__x: f32, __y: f32) f32;
pub extern fn totalorderf32(__x: [*c]const f32, __y: [*c]const f32) c_int;
pub extern fn totalordermagf32(__x: [*c]const f32, __y: [*c]const f32) c_int;
pub extern fn getpayloadf32(__x: [*c]const f32) f32;
pub extern fn __getpayloadf32(__x: [*c]const f32) f32;
pub extern fn setpayloadf32(__x: [*c]f32, __payload: f32) c_int;
pub extern fn setpayloadsigf32(__x: [*c]f32, __payload: f32) c_int;
pub extern fn acosf64(__x: f64) f64;
pub extern fn __acosf64(__x: f64) f64;
pub extern fn asinf64(__x: f64) f64;
pub extern fn __asinf64(__x: f64) f64;
pub extern fn atanf64(__x: f64) f64;
pub extern fn __atanf64(__x: f64) f64;
pub extern fn atan2f64(__y: f64, __x: f64) f64;
pub extern fn __atan2f64(__y: f64, __x: f64) f64;
pub extern fn cosf64(__x: f64) f64;
pub extern fn __cosf64(__x: f64) f64;
pub extern fn sinf64(__x: f64) f64;
pub extern fn __sinf64(__x: f64) f64;
pub extern fn tanf64(__x: f64) f64;
pub extern fn __tanf64(__x: f64) f64;
pub extern fn coshf64(__x: f64) f64;
pub extern fn __coshf64(__x: f64) f64;
pub extern fn sinhf64(__x: f64) f64;
pub extern fn __sinhf64(__x: f64) f64;
pub extern fn tanhf64(__x: f64) f64;
pub extern fn __tanhf64(__x: f64) f64;
pub extern fn sincosf64(__x: f64, __sinx: [*c]f64, __cosx: [*c]f64) void;
pub extern fn __sincosf64(__x: f64, __sinx: [*c]f64, __cosx: [*c]f64) void;
pub extern fn acoshf64(__x: f64) f64;
pub extern fn __acoshf64(__x: f64) f64;
pub extern fn asinhf64(__x: f64) f64;
pub extern fn __asinhf64(__x: f64) f64;
pub extern fn atanhf64(__x: f64) f64;
pub extern fn __atanhf64(__x: f64) f64;
pub extern fn expf64(__x: f64) f64;
pub extern fn __expf64(__x: f64) f64;
pub extern fn frexpf64(__x: f64, __exponent: [*c]c_int) f64;
pub extern fn __frexpf64(__x: f64, __exponent: [*c]c_int) f64;
pub extern fn ldexpf64(__x: f64, __exponent: c_int) f64;
pub extern fn __ldexpf64(__x: f64, __exponent: c_int) f64;
pub extern fn logf64(__x: f64) f64;
pub extern fn __logf64(__x: f64) f64;
pub extern fn log10f64(__x: f64) f64;
pub extern fn __log10f64(__x: f64) f64;
pub extern fn modff64(__x: f64, __iptr: [*c]f64) f64;
pub extern fn __modff64(__x: f64, __iptr: [*c]f64) f64;
pub extern fn exp10f64(__x: f64) f64;
pub extern fn __exp10f64(__x: f64) f64;
pub extern fn expm1f64(__x: f64) f64;
pub extern fn __expm1f64(__x: f64) f64;
pub extern fn log1pf64(__x: f64) f64;
pub extern fn __log1pf64(__x: f64) f64;
pub extern fn logbf64(__x: f64) f64;
pub extern fn __logbf64(__x: f64) f64;
pub extern fn exp2f64(__x: f64) f64;
pub extern fn __exp2f64(__x: f64) f64;
pub extern fn log2f64(__x: f64) f64;
pub extern fn __log2f64(__x: f64) f64;
pub extern fn powf64(__x: f64, __y: f64) f64;
pub extern fn __powf64(__x: f64, __y: f64) f64;
pub extern fn sqrtf64(__x: f64) f64;
pub extern fn __sqrtf64(__x: f64) f64;
pub extern fn hypotf64(__x: f64, __y: f64) f64;
pub extern fn __hypotf64(__x: f64, __y: f64) f64;
pub extern fn cbrtf64(__x: f64) f64;
pub extern fn __cbrtf64(__x: f64) f64;
pub extern fn ceilf64(__x: f64) f64;
pub extern fn __ceilf64(__x: f64) f64;
pub extern fn fabsf64(__x: f64) f64;
pub extern fn __fabsf64(__x: f64) f64;
pub extern fn floorf64(__x: f64) f64;
pub extern fn __floorf64(__x: f64) f64;
pub extern fn fmodf64(__x: f64, __y: f64) f64;
pub extern fn __fmodf64(__x: f64, __y: f64) f64;
pub extern fn copysignf64(__x: f64, __y: f64) f64;
pub extern fn __copysignf64(__x: f64, __y: f64) f64;
pub extern fn nanf64(__tagb: [*c]const u8) f64;
pub extern fn __nanf64(__tagb: [*c]const u8) f64;
pub extern fn j0f64(f64) f64;
pub extern fn __j0f64(f64) f64;
pub extern fn j1f64(f64) f64;
pub extern fn __j1f64(f64) f64;
pub extern fn jnf64(c_int, f64) f64;
pub extern fn __jnf64(c_int, f64) f64;
pub extern fn y0f64(f64) f64;
pub extern fn __y0f64(f64) f64;
pub extern fn y1f64(f64) f64;
pub extern fn __y1f64(f64) f64;
pub extern fn ynf64(c_int, f64) f64;
pub extern fn __ynf64(c_int, f64) f64;
pub extern fn erff64(f64) f64;
pub extern fn __erff64(f64) f64;
pub extern fn erfcf64(f64) f64;
pub extern fn __erfcf64(f64) f64;
pub extern fn lgammaf64(f64) f64;
pub extern fn __lgammaf64(f64) f64;
pub extern fn tgammaf64(f64) f64;
pub extern fn __tgammaf64(f64) f64;
pub extern fn lgammaf64_r(f64, __signgamp: [*c]c_int) f64;
pub extern fn __lgammaf64_r(f64, __signgamp: [*c]c_int) f64;
pub extern fn rintf64(__x: f64) f64;
pub extern fn __rintf64(__x: f64) f64;
pub extern fn nextafterf64(__x: f64, __y: f64) f64;
pub extern fn __nextafterf64(__x: f64, __y: f64) f64;
pub extern fn nextdownf64(__x: f64) f64;
pub extern fn __nextdownf64(__x: f64) f64;
pub extern fn nextupf64(__x: f64) f64;
pub extern fn __nextupf64(__x: f64) f64;
pub extern fn remainderf64(__x: f64, __y: f64) f64;
pub extern fn __remainderf64(__x: f64, __y: f64) f64;
pub extern fn scalbnf64(__x: f64, __n: c_int) f64;
pub extern fn __scalbnf64(__x: f64, __n: c_int) f64;
pub extern fn ilogbf64(__x: f64) c_int;
pub extern fn __ilogbf64(__x: f64) c_int;
pub extern fn llogbf64(__x: f64) c_long;
pub extern fn __llogbf64(__x: f64) c_long;
pub extern fn scalblnf64(__x: f64, __n: c_long) f64;
pub extern fn __scalblnf64(__x: f64, __n: c_long) f64;
pub extern fn nearbyintf64(__x: f64) f64;
pub extern fn __nearbyintf64(__x: f64) f64;
pub extern fn roundf64(__x: f64) f64;
pub extern fn __roundf64(__x: f64) f64;
pub extern fn truncf64(__x: f64) f64;
pub extern fn __truncf64(__x: f64) f64;
pub extern fn remquof64(__x: f64, __y: f64, __quo: [*c]c_int) f64;
pub extern fn __remquof64(__x: f64, __y: f64, __quo: [*c]c_int) f64;
pub extern fn lrintf64(__x: f64) c_long;
pub extern fn __lrintf64(__x: f64) c_long;
pub extern fn llrintf64(__x: f64) c_longlong;
pub extern fn __llrintf64(__x: f64) c_longlong;
pub extern fn lroundf64(__x: f64) c_long;
pub extern fn __lroundf64(__x: f64) c_long;
pub extern fn llroundf64(__x: f64) c_longlong;
pub extern fn __llroundf64(__x: f64) c_longlong;
pub extern fn fdimf64(__x: f64, __y: f64) f64;
pub extern fn __fdimf64(__x: f64, __y: f64) f64;
pub extern fn fmaxf64(__x: f64, __y: f64) f64;
pub extern fn __fmaxf64(__x: f64, __y: f64) f64;
pub extern fn fminf64(__x: f64, __y: f64) f64;
pub extern fn __fminf64(__x: f64, __y: f64) f64;
pub extern fn fmaf64(__x: f64, __y: f64, __z: f64) f64;
pub extern fn __fmaf64(__x: f64, __y: f64, __z: f64) f64;
pub extern fn roundevenf64(__x: f64) f64;
pub extern fn __roundevenf64(__x: f64) f64;
pub extern fn fromfpf64(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpf64(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpf64(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpf64(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn fromfpxf64(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpxf64(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpxf64(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpxf64(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn canonicalizef64(__cx: [*c]f64, __x: [*c]const f64) c_int;
pub extern fn fmaxmagf64(__x: f64, __y: f64) f64;
pub extern fn __fmaxmagf64(__x: f64, __y: f64) f64;
pub extern fn fminmagf64(__x: f64, __y: f64) f64;
pub extern fn __fminmagf64(__x: f64, __y: f64) f64;
pub extern fn fmaximumf64(__x: f64, __y: f64) f64;
pub extern fn __fmaximumf64(__x: f64, __y: f64) f64;
pub extern fn fminimumf64(__x: f64, __y: f64) f64;
pub extern fn __fminimumf64(__x: f64, __y: f64) f64;
pub extern fn fmaximum_numf64(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_numf64(__x: f64, __y: f64) f64;
pub extern fn fminimum_numf64(__x: f64, __y: f64) f64;
pub extern fn __fminimum_numf64(__x: f64, __y: f64) f64;
pub extern fn fmaximum_magf64(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_magf64(__x: f64, __y: f64) f64;
pub extern fn fminimum_magf64(__x: f64, __y: f64) f64;
pub extern fn __fminimum_magf64(__x: f64, __y: f64) f64;
pub extern fn fmaximum_mag_numf64(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_mag_numf64(__x: f64, __y: f64) f64;
pub extern fn fminimum_mag_numf64(__x: f64, __y: f64) f64;
pub extern fn __fminimum_mag_numf64(__x: f64, __y: f64) f64;
pub extern fn totalorderf64(__x: [*c]const f64, __y: [*c]const f64) c_int;
pub extern fn totalordermagf64(__x: [*c]const f64, __y: [*c]const f64) c_int;
pub extern fn getpayloadf64(__x: [*c]const f64) f64;
pub extern fn __getpayloadf64(__x: [*c]const f64) f64;
pub extern fn setpayloadf64(__x: [*c]f64, __payload: f64) c_int;
pub extern fn setpayloadsigf64(__x: [*c]f64, __payload: f64) c_int;
pub extern fn __fpclassifyf128(__value: f128) c_int;
pub extern fn __signbitf128(__value: f128) c_int;
pub extern fn __isinff128(__value: f128) c_int;
pub extern fn __finitef128(__value: f128) c_int;
pub extern fn __isnanf128(__value: f128) c_int;
pub extern fn __iseqsigf128(__x: f128, __y: f128) c_int;
pub extern fn __issignalingf128(__value: f128) c_int;
pub extern fn acosf128(__x: f128) f128;
pub extern fn __acosf128(__x: f128) f128;
pub extern fn asinf128(__x: f128) f128;
pub extern fn __asinf128(__x: f128) f128;
pub extern fn atanf128(__x: f128) f128;
pub extern fn __atanf128(__x: f128) f128;
pub extern fn atan2f128(__y: f128, __x: f128) f128;
pub extern fn __atan2f128(__y: f128, __x: f128) f128;
pub extern fn cosf128(__x: f128) f128;
pub extern fn __cosf128(__x: f128) f128;
pub extern fn sinf128(__x: f128) f128;
pub extern fn __sinf128(__x: f128) f128;
pub extern fn tanf128(__x: f128) f128;
pub extern fn __tanf128(__x: f128) f128;
pub extern fn coshf128(__x: f128) f128;
pub extern fn __coshf128(__x: f128) f128;
pub extern fn sinhf128(__x: f128) f128;
pub extern fn __sinhf128(__x: f128) f128;
pub extern fn tanhf128(__x: f128) f128;
pub extern fn __tanhf128(__x: f128) f128;
pub extern fn sincosf128(__x: f128, __sinx: [*c]f128, __cosx: [*c]f128) void;
pub extern fn __sincosf128(__x: f128, __sinx: [*c]f128, __cosx: [*c]f128) void;
pub extern fn acoshf128(__x: f128) f128;
pub extern fn __acoshf128(__x: f128) f128;
pub extern fn asinhf128(__x: f128) f128;
pub extern fn __asinhf128(__x: f128) f128;
pub extern fn atanhf128(__x: f128) f128;
pub extern fn __atanhf128(__x: f128) f128;
pub extern fn expf128(__x: f128) f128;
pub extern fn __expf128(__x: f128) f128;
pub extern fn frexpf128(__x: f128, __exponent: [*c]c_int) f128;
pub extern fn __frexpf128(__x: f128, __exponent: [*c]c_int) f128;
pub extern fn ldexpf128(__x: f128, __exponent: c_int) f128;
pub extern fn __ldexpf128(__x: f128, __exponent: c_int) f128;
pub extern fn logf128(__x: f128) f128;
pub extern fn __logf128(__x: f128) f128;
pub extern fn log10f128(__x: f128) f128;
pub extern fn __log10f128(__x: f128) f128;
pub extern fn modff128(__x: f128, __iptr: [*c]f128) f128;
pub extern fn __modff128(__x: f128, __iptr: [*c]f128) f128;
pub extern fn exp10f128(__x: f128) f128;
pub extern fn __exp10f128(__x: f128) f128;
pub extern fn expm1f128(__x: f128) f128;
pub extern fn __expm1f128(__x: f128) f128;
pub extern fn log1pf128(__x: f128) f128;
pub extern fn __log1pf128(__x: f128) f128;
pub extern fn logbf128(__x: f128) f128;
pub extern fn __logbf128(__x: f128) f128;
pub extern fn exp2f128(__x: f128) f128;
pub extern fn __exp2f128(__x: f128) f128;
pub extern fn log2f128(__x: f128) f128;
pub extern fn __log2f128(__x: f128) f128;
pub extern fn powf128(__x: f128, __y: f128) f128;
pub extern fn __powf128(__x: f128, __y: f128) f128;
pub extern fn sqrtf128(__x: f128) f128;
pub extern fn __sqrtf128(__x: f128) f128;
pub extern fn hypotf128(__x: f128, __y: f128) f128;
pub extern fn __hypotf128(__x: f128, __y: f128) f128;
pub extern fn cbrtf128(__x: f128) f128;
pub extern fn __cbrtf128(__x: f128) f128;
pub extern fn ceilf128(__x: f128) f128;
pub extern fn __ceilf128(__x: f128) f128;
pub extern fn fabsf128(__x: f128) f128;
pub extern fn __fabsf128(__x: f128) f128;
pub extern fn floorf128(__x: f128) f128;
pub extern fn __floorf128(__x: f128) f128;
pub extern fn fmodf128(__x: f128, __y: f128) f128;
pub extern fn __fmodf128(__x: f128, __y: f128) f128;
pub extern fn copysignf128(__x: f128, __y: f128) f128;
pub extern fn __copysignf128(__x: f128, __y: f128) f128;
pub extern fn nanf128(__tagb: [*c]const u8) f128;
pub extern fn __nanf128(__tagb: [*c]const u8) f128;
pub extern fn j0f128(f128) f128;
pub extern fn __j0f128(f128) f128;
pub extern fn j1f128(f128) f128;
pub extern fn __j1f128(f128) f128;
pub extern fn jnf128(c_int, f128) f128;
pub extern fn __jnf128(c_int, f128) f128;
pub extern fn y0f128(f128) f128;
pub extern fn __y0f128(f128) f128;
pub extern fn y1f128(f128) f128;
pub extern fn __y1f128(f128) f128;
pub extern fn ynf128(c_int, f128) f128;
pub extern fn __ynf128(c_int, f128) f128;
pub extern fn erff128(f128) f128;
pub extern fn __erff128(f128) f128;
pub extern fn erfcf128(f128) f128;
pub extern fn __erfcf128(f128) f128;
pub extern fn lgammaf128(f128) f128;
pub extern fn __lgammaf128(f128) f128;
pub extern fn tgammaf128(f128) f128;
pub extern fn __tgammaf128(f128) f128;
pub extern fn lgammaf128_r(f128, __signgamp: [*c]c_int) f128;
pub extern fn __lgammaf128_r(f128, __signgamp: [*c]c_int) f128;
pub extern fn rintf128(__x: f128) f128;
pub extern fn __rintf128(__x: f128) f128;
pub extern fn nextafterf128(__x: f128, __y: f128) f128;
pub extern fn __nextafterf128(__x: f128, __y: f128) f128;
pub extern fn nextdownf128(__x: f128) f128;
pub extern fn __nextdownf128(__x: f128) f128;
pub extern fn nextupf128(__x: f128) f128;
pub extern fn __nextupf128(__x: f128) f128;
pub extern fn remainderf128(__x: f128, __y: f128) f128;
pub extern fn __remainderf128(__x: f128, __y: f128) f128;
pub extern fn scalbnf128(__x: f128, __n: c_int) f128;
pub extern fn __scalbnf128(__x: f128, __n: c_int) f128;
pub extern fn ilogbf128(__x: f128) c_int;
pub extern fn __ilogbf128(__x: f128) c_int;
pub extern fn llogbf128(__x: f128) c_long;
pub extern fn __llogbf128(__x: f128) c_long;
pub extern fn scalblnf128(__x: f128, __n: c_long) f128;
pub extern fn __scalblnf128(__x: f128, __n: c_long) f128;
pub extern fn nearbyintf128(__x: f128) f128;
pub extern fn __nearbyintf128(__x: f128) f128;
pub extern fn roundf128(__x: f128) f128;
pub extern fn __roundf128(__x: f128) f128;
pub extern fn truncf128(__x: f128) f128;
pub extern fn __truncf128(__x: f128) f128;
pub extern fn remquof128(__x: f128, __y: f128, __quo: [*c]c_int) f128;
pub extern fn __remquof128(__x: f128, __y: f128, __quo: [*c]c_int) f128;
pub extern fn lrintf128(__x: f128) c_long;
pub extern fn __lrintf128(__x: f128) c_long;
pub extern fn llrintf128(__x: f128) c_longlong;
pub extern fn __llrintf128(__x: f128) c_longlong;
pub extern fn lroundf128(__x: f128) c_long;
pub extern fn __lroundf128(__x: f128) c_long;
pub extern fn llroundf128(__x: f128) c_longlong;
pub extern fn __llroundf128(__x: f128) c_longlong;
pub extern fn fdimf128(__x: f128, __y: f128) f128;
pub extern fn __fdimf128(__x: f128, __y: f128) f128;
pub extern fn fmaxf128(__x: f128, __y: f128) f128;
pub extern fn __fmaxf128(__x: f128, __y: f128) f128;
pub extern fn fminf128(__x: f128, __y: f128) f128;
pub extern fn __fminf128(__x: f128, __y: f128) f128;
pub extern fn fmaf128(__x: f128, __y: f128, __z: f128) f128;
pub extern fn __fmaf128(__x: f128, __y: f128, __z: f128) f128;
pub extern fn roundevenf128(__x: f128) f128;
pub extern fn __roundevenf128(__x: f128) f128;
pub extern fn fromfpf128(__x: f128, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpf128(__x: f128, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpf128(__x: f128, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpf128(__x: f128, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn fromfpxf128(__x: f128, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpxf128(__x: f128, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpxf128(__x: f128, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpxf128(__x: f128, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn canonicalizef128(__cx: [*c]f128, __x: [*c]const f128) c_int;
pub extern fn fmaxmagf128(__x: f128, __y: f128) f128;
pub extern fn __fmaxmagf128(__x: f128, __y: f128) f128;
pub extern fn fminmagf128(__x: f128, __y: f128) f128;
pub extern fn __fminmagf128(__x: f128, __y: f128) f128;
pub extern fn fmaximumf128(__x: f128, __y: f128) f128;
pub extern fn __fmaximumf128(__x: f128, __y: f128) f128;
pub extern fn fminimumf128(__x: f128, __y: f128) f128;
pub extern fn __fminimumf128(__x: f128, __y: f128) f128;
pub extern fn fmaximum_numf128(__x: f128, __y: f128) f128;
pub extern fn __fmaximum_numf128(__x: f128, __y: f128) f128;
pub extern fn fminimum_numf128(__x: f128, __y: f128) f128;
pub extern fn __fminimum_numf128(__x: f128, __y: f128) f128;
pub extern fn fmaximum_magf128(__x: f128, __y: f128) f128;
pub extern fn __fmaximum_magf128(__x: f128, __y: f128) f128;
pub extern fn fminimum_magf128(__x: f128, __y: f128) f128;
pub extern fn __fminimum_magf128(__x: f128, __y: f128) f128;
pub extern fn fmaximum_mag_numf128(__x: f128, __y: f128) f128;
pub extern fn __fmaximum_mag_numf128(__x: f128, __y: f128) f128;
pub extern fn fminimum_mag_numf128(__x: f128, __y: f128) f128;
pub extern fn __fminimum_mag_numf128(__x: f128, __y: f128) f128;
pub extern fn totalorderf128(__x: [*c]const f128, __y: [*c]const f128) c_int;
pub extern fn totalordermagf128(__x: [*c]const f128, __y: [*c]const f128) c_int;
pub extern fn getpayloadf128(__x: [*c]const f128) f128;
pub extern fn __getpayloadf128(__x: [*c]const f128) f128;
pub extern fn setpayloadf128(__x: [*c]f128, __payload: f128) c_int;
pub extern fn setpayloadsigf128(__x: [*c]f128, __payload: f128) c_int;
pub extern fn acosf32x(__x: f64) f64;
pub extern fn __acosf32x(__x: f64) f64;
pub extern fn asinf32x(__x: f64) f64;
pub extern fn __asinf32x(__x: f64) f64;
pub extern fn atanf32x(__x: f64) f64;
pub extern fn __atanf32x(__x: f64) f64;
pub extern fn atan2f32x(__y: f64, __x: f64) f64;
pub extern fn __atan2f32x(__y: f64, __x: f64) f64;
pub extern fn cosf32x(__x: f64) f64;
pub extern fn __cosf32x(__x: f64) f64;
pub extern fn sinf32x(__x: f64) f64;
pub extern fn __sinf32x(__x: f64) f64;
pub extern fn tanf32x(__x: f64) f64;
pub extern fn __tanf32x(__x: f64) f64;
pub extern fn coshf32x(__x: f64) f64;
pub extern fn __coshf32x(__x: f64) f64;
pub extern fn sinhf32x(__x: f64) f64;
pub extern fn __sinhf32x(__x: f64) f64;
pub extern fn tanhf32x(__x: f64) f64;
pub extern fn __tanhf32x(__x: f64) f64;
pub extern fn sincosf32x(__x: f64, __sinx: [*c]f64, __cosx: [*c]f64) void;
pub extern fn __sincosf32x(__x: f64, __sinx: [*c]f64, __cosx: [*c]f64) void;
pub extern fn acoshf32x(__x: f64) f64;
pub extern fn __acoshf32x(__x: f64) f64;
pub extern fn asinhf32x(__x: f64) f64;
pub extern fn __asinhf32x(__x: f64) f64;
pub extern fn atanhf32x(__x: f64) f64;
pub extern fn __atanhf32x(__x: f64) f64;
pub extern fn expf32x(__x: f64) f64;
pub extern fn __expf32x(__x: f64) f64;
pub extern fn frexpf32x(__x: f64, __exponent: [*c]c_int) f64;
pub extern fn __frexpf32x(__x: f64, __exponent: [*c]c_int) f64;
pub extern fn ldexpf32x(__x: f64, __exponent: c_int) f64;
pub extern fn __ldexpf32x(__x: f64, __exponent: c_int) f64;
pub extern fn logf32x(__x: f64) f64;
pub extern fn __logf32x(__x: f64) f64;
pub extern fn log10f32x(__x: f64) f64;
pub extern fn __log10f32x(__x: f64) f64;
pub extern fn modff32x(__x: f64, __iptr: [*c]f64) f64;
pub extern fn __modff32x(__x: f64, __iptr: [*c]f64) f64;
pub extern fn exp10f32x(__x: f64) f64;
pub extern fn __exp10f32x(__x: f64) f64;
pub extern fn expm1f32x(__x: f64) f64;
pub extern fn __expm1f32x(__x: f64) f64;
pub extern fn log1pf32x(__x: f64) f64;
pub extern fn __log1pf32x(__x: f64) f64;
pub extern fn logbf32x(__x: f64) f64;
pub extern fn __logbf32x(__x: f64) f64;
pub extern fn exp2f32x(__x: f64) f64;
pub extern fn __exp2f32x(__x: f64) f64;
pub extern fn log2f32x(__x: f64) f64;
pub extern fn __log2f32x(__x: f64) f64;
pub extern fn powf32x(__x: f64, __y: f64) f64;
pub extern fn __powf32x(__x: f64, __y: f64) f64;
pub extern fn sqrtf32x(__x: f64) f64;
pub extern fn __sqrtf32x(__x: f64) f64;
pub extern fn hypotf32x(__x: f64, __y: f64) f64;
pub extern fn __hypotf32x(__x: f64, __y: f64) f64;
pub extern fn cbrtf32x(__x: f64) f64;
pub extern fn __cbrtf32x(__x: f64) f64;
pub extern fn ceilf32x(__x: f64) f64;
pub extern fn __ceilf32x(__x: f64) f64;
pub extern fn fabsf32x(__x: f64) f64;
pub extern fn __fabsf32x(__x: f64) f64;
pub extern fn floorf32x(__x: f64) f64;
pub extern fn __floorf32x(__x: f64) f64;
pub extern fn fmodf32x(__x: f64, __y: f64) f64;
pub extern fn __fmodf32x(__x: f64, __y: f64) f64;
pub extern fn copysignf32x(__x: f64, __y: f64) f64;
pub extern fn __copysignf32x(__x: f64, __y: f64) f64;
pub extern fn nanf32x(__tagb: [*c]const u8) f64;
pub extern fn __nanf32x(__tagb: [*c]const u8) f64;
pub extern fn j0f32x(f64) f64;
pub extern fn __j0f32x(f64) f64;
pub extern fn j1f32x(f64) f64;
pub extern fn __j1f32x(f64) f64;
pub extern fn jnf32x(c_int, f64) f64;
pub extern fn __jnf32x(c_int, f64) f64;
pub extern fn y0f32x(f64) f64;
pub extern fn __y0f32x(f64) f64;
pub extern fn y1f32x(f64) f64;
pub extern fn __y1f32x(f64) f64;
pub extern fn ynf32x(c_int, f64) f64;
pub extern fn __ynf32x(c_int, f64) f64;
pub extern fn erff32x(f64) f64;
pub extern fn __erff32x(f64) f64;
pub extern fn erfcf32x(f64) f64;
pub extern fn __erfcf32x(f64) f64;
pub extern fn lgammaf32x(f64) f64;
pub extern fn __lgammaf32x(f64) f64;
pub extern fn tgammaf32x(f64) f64;
pub extern fn __tgammaf32x(f64) f64;
pub extern fn lgammaf32x_r(f64, __signgamp: [*c]c_int) f64;
pub extern fn __lgammaf32x_r(f64, __signgamp: [*c]c_int) f64;
pub extern fn rintf32x(__x: f64) f64;
pub extern fn __rintf32x(__x: f64) f64;
pub extern fn nextafterf32x(__x: f64, __y: f64) f64;
pub extern fn __nextafterf32x(__x: f64, __y: f64) f64;
pub extern fn nextdownf32x(__x: f64) f64;
pub extern fn __nextdownf32x(__x: f64) f64;
pub extern fn nextupf32x(__x: f64) f64;
pub extern fn __nextupf32x(__x: f64) f64;
pub extern fn remainderf32x(__x: f64, __y: f64) f64;
pub extern fn __remainderf32x(__x: f64, __y: f64) f64;
pub extern fn scalbnf32x(__x: f64, __n: c_int) f64;
pub extern fn __scalbnf32x(__x: f64, __n: c_int) f64;
pub extern fn ilogbf32x(__x: f64) c_int;
pub extern fn __ilogbf32x(__x: f64) c_int;
pub extern fn llogbf32x(__x: f64) c_long;
pub extern fn __llogbf32x(__x: f64) c_long;
pub extern fn scalblnf32x(__x: f64, __n: c_long) f64;
pub extern fn __scalblnf32x(__x: f64, __n: c_long) f64;
pub extern fn nearbyintf32x(__x: f64) f64;
pub extern fn __nearbyintf32x(__x: f64) f64;
pub extern fn roundf32x(__x: f64) f64;
pub extern fn __roundf32x(__x: f64) f64;
pub extern fn truncf32x(__x: f64) f64;
pub extern fn __truncf32x(__x: f64) f64;
pub extern fn remquof32x(__x: f64, __y: f64, __quo: [*c]c_int) f64;
pub extern fn __remquof32x(__x: f64, __y: f64, __quo: [*c]c_int) f64;
pub extern fn lrintf32x(__x: f64) c_long;
pub extern fn __lrintf32x(__x: f64) c_long;
pub extern fn llrintf32x(__x: f64) c_longlong;
pub extern fn __llrintf32x(__x: f64) c_longlong;
pub extern fn lroundf32x(__x: f64) c_long;
pub extern fn __lroundf32x(__x: f64) c_long;
pub extern fn llroundf32x(__x: f64) c_longlong;
pub extern fn __llroundf32x(__x: f64) c_longlong;
pub extern fn fdimf32x(__x: f64, __y: f64) f64;
pub extern fn __fdimf32x(__x: f64, __y: f64) f64;
pub extern fn fmaxf32x(__x: f64, __y: f64) f64;
pub extern fn __fmaxf32x(__x: f64, __y: f64) f64;
pub extern fn fminf32x(__x: f64, __y: f64) f64;
pub extern fn __fminf32x(__x: f64, __y: f64) f64;
pub extern fn fmaf32x(__x: f64, __y: f64, __z: f64) f64;
pub extern fn __fmaf32x(__x: f64, __y: f64, __z: f64) f64;
pub extern fn roundevenf32x(__x: f64) f64;
pub extern fn __roundevenf32x(__x: f64) f64;
pub extern fn fromfpf32x(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpf32x(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpf32x(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpf32x(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn fromfpxf32x(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpxf32x(__x: f64, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpxf32x(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpxf32x(__x: f64, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn canonicalizef32x(__cx: [*c]f64, __x: [*c]const f64) c_int;
pub extern fn fmaxmagf32x(__x: f64, __y: f64) f64;
pub extern fn __fmaxmagf32x(__x: f64, __y: f64) f64;
pub extern fn fminmagf32x(__x: f64, __y: f64) f64;
pub extern fn __fminmagf32x(__x: f64, __y: f64) f64;
pub extern fn fmaximumf32x(__x: f64, __y: f64) f64;
pub extern fn __fmaximumf32x(__x: f64, __y: f64) f64;
pub extern fn fminimumf32x(__x: f64, __y: f64) f64;
pub extern fn __fminimumf32x(__x: f64, __y: f64) f64;
pub extern fn fmaximum_numf32x(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_numf32x(__x: f64, __y: f64) f64;
pub extern fn fminimum_numf32x(__x: f64, __y: f64) f64;
pub extern fn __fminimum_numf32x(__x: f64, __y: f64) f64;
pub extern fn fmaximum_magf32x(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_magf32x(__x: f64, __y: f64) f64;
pub extern fn fminimum_magf32x(__x: f64, __y: f64) f64;
pub extern fn __fminimum_magf32x(__x: f64, __y: f64) f64;
pub extern fn fmaximum_mag_numf32x(__x: f64, __y: f64) f64;
pub extern fn __fmaximum_mag_numf32x(__x: f64, __y: f64) f64;
pub extern fn fminimum_mag_numf32x(__x: f64, __y: f64) f64;
pub extern fn __fminimum_mag_numf32x(__x: f64, __y: f64) f64;
pub extern fn totalorderf32x(__x: [*c]const f64, __y: [*c]const f64) c_int;
pub extern fn totalordermagf32x(__x: [*c]const f64, __y: [*c]const f64) c_int;
pub extern fn getpayloadf32x(__x: [*c]const f64) f64;
pub extern fn __getpayloadf32x(__x: [*c]const f64) f64;
pub extern fn setpayloadf32x(__x: [*c]f64, __payload: f64) c_int;
pub extern fn setpayloadsigf32x(__x: [*c]f64, __payload: f64) c_int;
pub extern fn acosf64x(__x: c_longdouble) c_longdouble;
pub extern fn __acosf64x(__x: c_longdouble) c_longdouble;
pub extern fn asinf64x(__x: c_longdouble) c_longdouble;
pub extern fn __asinf64x(__x: c_longdouble) c_longdouble;
pub extern fn atanf64x(__x: c_longdouble) c_longdouble;
pub extern fn __atanf64x(__x: c_longdouble) c_longdouble;
pub extern fn atan2f64x(__y: c_longdouble, __x: c_longdouble) c_longdouble;
pub extern fn __atan2f64x(__y: c_longdouble, __x: c_longdouble) c_longdouble;
pub extern fn cosf64x(__x: c_longdouble) c_longdouble;
pub extern fn __cosf64x(__x: c_longdouble) c_longdouble;
pub extern fn sinf64x(__x: c_longdouble) c_longdouble;
pub extern fn __sinf64x(__x: c_longdouble) c_longdouble;
pub extern fn tanf64x(__x: c_longdouble) c_longdouble;
pub extern fn __tanf64x(__x: c_longdouble) c_longdouble;
pub extern fn coshf64x(__x: c_longdouble) c_longdouble;
pub extern fn __coshf64x(__x: c_longdouble) c_longdouble;
pub extern fn sinhf64x(__x: c_longdouble) c_longdouble;
pub extern fn __sinhf64x(__x: c_longdouble) c_longdouble;
pub extern fn tanhf64x(__x: c_longdouble) c_longdouble;
pub extern fn __tanhf64x(__x: c_longdouble) c_longdouble;
pub extern fn sincosf64x(__x: c_longdouble, __sinx: [*c]c_longdouble, __cosx: [*c]c_longdouble) void;
pub extern fn __sincosf64x(__x: c_longdouble, __sinx: [*c]c_longdouble, __cosx: [*c]c_longdouble) void;
pub extern fn acoshf64x(__x: c_longdouble) c_longdouble;
pub extern fn __acoshf64x(__x: c_longdouble) c_longdouble;
pub extern fn asinhf64x(__x: c_longdouble) c_longdouble;
pub extern fn __asinhf64x(__x: c_longdouble) c_longdouble;
pub extern fn atanhf64x(__x: c_longdouble) c_longdouble;
pub extern fn __atanhf64x(__x: c_longdouble) c_longdouble;
pub extern fn expf64x(__x: c_longdouble) c_longdouble;
pub extern fn __expf64x(__x: c_longdouble) c_longdouble;
pub extern fn frexpf64x(__x: c_longdouble, __exponent: [*c]c_int) c_longdouble;
pub extern fn __frexpf64x(__x: c_longdouble, __exponent: [*c]c_int) c_longdouble;
pub extern fn ldexpf64x(__x: c_longdouble, __exponent: c_int) c_longdouble;
pub extern fn __ldexpf64x(__x: c_longdouble, __exponent: c_int) c_longdouble;
pub extern fn logf64x(__x: c_longdouble) c_longdouble;
pub extern fn __logf64x(__x: c_longdouble) c_longdouble;
pub extern fn log10f64x(__x: c_longdouble) c_longdouble;
pub extern fn __log10f64x(__x: c_longdouble) c_longdouble;
pub extern fn modff64x(__x: c_longdouble, __iptr: [*c]c_longdouble) c_longdouble;
pub extern fn __modff64x(__x: c_longdouble, __iptr: [*c]c_longdouble) c_longdouble;
pub extern fn exp10f64x(__x: c_longdouble) c_longdouble;
pub extern fn __exp10f64x(__x: c_longdouble) c_longdouble;
pub extern fn expm1f64x(__x: c_longdouble) c_longdouble;
pub extern fn __expm1f64x(__x: c_longdouble) c_longdouble;
pub extern fn log1pf64x(__x: c_longdouble) c_longdouble;
pub extern fn __log1pf64x(__x: c_longdouble) c_longdouble;
pub extern fn logbf64x(__x: c_longdouble) c_longdouble;
pub extern fn __logbf64x(__x: c_longdouble) c_longdouble;
pub extern fn exp2f64x(__x: c_longdouble) c_longdouble;
pub extern fn __exp2f64x(__x: c_longdouble) c_longdouble;
pub extern fn log2f64x(__x: c_longdouble) c_longdouble;
pub extern fn __log2f64x(__x: c_longdouble) c_longdouble;
pub extern fn powf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __powf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn sqrtf64x(__x: c_longdouble) c_longdouble;
pub extern fn __sqrtf64x(__x: c_longdouble) c_longdouble;
pub extern fn hypotf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __hypotf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn cbrtf64x(__x: c_longdouble) c_longdouble;
pub extern fn __cbrtf64x(__x: c_longdouble) c_longdouble;
pub extern fn ceilf64x(__x: c_longdouble) c_longdouble;
pub extern fn __ceilf64x(__x: c_longdouble) c_longdouble;
pub extern fn fabsf64x(__x: c_longdouble) c_longdouble;
pub extern fn __fabsf64x(__x: c_longdouble) c_longdouble;
pub extern fn floorf64x(__x: c_longdouble) c_longdouble;
pub extern fn __floorf64x(__x: c_longdouble) c_longdouble;
pub extern fn fmodf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmodf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn copysignf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __copysignf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn nanf64x(__tagb: [*c]const u8) c_longdouble;
pub extern fn __nanf64x(__tagb: [*c]const u8) c_longdouble;
pub extern fn j0f64x(c_longdouble) c_longdouble;
pub extern fn __j0f64x(c_longdouble) c_longdouble;
pub extern fn j1f64x(c_longdouble) c_longdouble;
pub extern fn __j1f64x(c_longdouble) c_longdouble;
pub extern fn jnf64x(c_int, c_longdouble) c_longdouble;
pub extern fn __jnf64x(c_int, c_longdouble) c_longdouble;
pub extern fn y0f64x(c_longdouble) c_longdouble;
pub extern fn __y0f64x(c_longdouble) c_longdouble;
pub extern fn y1f64x(c_longdouble) c_longdouble;
pub extern fn __y1f64x(c_longdouble) c_longdouble;
pub extern fn ynf64x(c_int, c_longdouble) c_longdouble;
pub extern fn __ynf64x(c_int, c_longdouble) c_longdouble;
pub extern fn erff64x(c_longdouble) c_longdouble;
pub extern fn __erff64x(c_longdouble) c_longdouble;
pub extern fn erfcf64x(c_longdouble) c_longdouble;
pub extern fn __erfcf64x(c_longdouble) c_longdouble;
pub extern fn lgammaf64x(c_longdouble) c_longdouble;
pub extern fn __lgammaf64x(c_longdouble) c_longdouble;
pub extern fn tgammaf64x(c_longdouble) c_longdouble;
pub extern fn __tgammaf64x(c_longdouble) c_longdouble;
pub extern fn lgammaf64x_r(c_longdouble, __signgamp: [*c]c_int) c_longdouble;
pub extern fn __lgammaf64x_r(c_longdouble, __signgamp: [*c]c_int) c_longdouble;
pub extern fn rintf64x(__x: c_longdouble) c_longdouble;
pub extern fn __rintf64x(__x: c_longdouble) c_longdouble;
pub extern fn nextafterf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __nextafterf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn nextdownf64x(__x: c_longdouble) c_longdouble;
pub extern fn __nextdownf64x(__x: c_longdouble) c_longdouble;
pub extern fn nextupf64x(__x: c_longdouble) c_longdouble;
pub extern fn __nextupf64x(__x: c_longdouble) c_longdouble;
pub extern fn remainderf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __remainderf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn scalbnf64x(__x: c_longdouble, __n: c_int) c_longdouble;
pub extern fn __scalbnf64x(__x: c_longdouble, __n: c_int) c_longdouble;
pub extern fn ilogbf64x(__x: c_longdouble) c_int;
pub extern fn __ilogbf64x(__x: c_longdouble) c_int;
pub extern fn llogbf64x(__x: c_longdouble) c_long;
pub extern fn __llogbf64x(__x: c_longdouble) c_long;
pub extern fn scalblnf64x(__x: c_longdouble, __n: c_long) c_longdouble;
pub extern fn __scalblnf64x(__x: c_longdouble, __n: c_long) c_longdouble;
pub extern fn nearbyintf64x(__x: c_longdouble) c_longdouble;
pub extern fn __nearbyintf64x(__x: c_longdouble) c_longdouble;
pub extern fn roundf64x(__x: c_longdouble) c_longdouble;
pub extern fn __roundf64x(__x: c_longdouble) c_longdouble;
pub extern fn truncf64x(__x: c_longdouble) c_longdouble;
pub extern fn __truncf64x(__x: c_longdouble) c_longdouble;
pub extern fn remquof64x(__x: c_longdouble, __y: c_longdouble, __quo: [*c]c_int) c_longdouble;
pub extern fn __remquof64x(__x: c_longdouble, __y: c_longdouble, __quo: [*c]c_int) c_longdouble;
pub extern fn lrintf64x(__x: c_longdouble) c_long;
pub extern fn __lrintf64x(__x: c_longdouble) c_long;
pub extern fn llrintf64x(__x: c_longdouble) c_longlong;
pub extern fn __llrintf64x(__x: c_longdouble) c_longlong;
pub extern fn lroundf64x(__x: c_longdouble) c_long;
pub extern fn __lroundf64x(__x: c_longdouble) c_long;
pub extern fn llroundf64x(__x: c_longdouble) c_longlong;
pub extern fn __llroundf64x(__x: c_longdouble) c_longlong;
pub extern fn fdimf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fdimf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaxf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaxf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaf64x(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) c_longdouble;
pub extern fn __fmaf64x(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) c_longdouble;
pub extern fn roundevenf64x(__x: c_longdouble) c_longdouble;
pub extern fn __roundevenf64x(__x: c_longdouble) c_longdouble;
pub extern fn fromfpf64x(__x: c_longdouble, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpf64x(__x: c_longdouble, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpf64x(__x: c_longdouble, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpf64x(__x: c_longdouble, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn fromfpxf64x(__x: c_longdouble, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn __fromfpxf64x(__x: c_longdouble, __round: c_int, __width: c_uint) __intmax_t;
pub extern fn ufromfpxf64x(__x: c_longdouble, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn __ufromfpxf64x(__x: c_longdouble, __round: c_int, __width: c_uint) __uintmax_t;
pub extern fn canonicalizef64x(__cx: [*c]c_longdouble, __x: [*c]const c_longdouble) c_int;
pub extern fn fmaxmagf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaxmagf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminmagf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminmagf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaximumf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaximumf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminimumf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminimumf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaximum_numf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaximum_numf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminimum_numf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminimum_numf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaximum_magf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaximum_magf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminimum_magf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminimum_magf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fmaximum_mag_numf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fmaximum_mag_numf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn fminimum_mag_numf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn __fminimum_mag_numf64x(__x: c_longdouble, __y: c_longdouble) c_longdouble;
pub extern fn totalorderf64x(__x: [*c]const c_longdouble, __y: [*c]const c_longdouble) c_int;
pub extern fn totalordermagf64x(__x: [*c]const c_longdouble, __y: [*c]const c_longdouble) c_int;
pub extern fn getpayloadf64x(__x: [*c]const c_longdouble) c_longdouble;
pub extern fn __getpayloadf64x(__x: [*c]const c_longdouble) c_longdouble;
pub extern fn setpayloadf64x(__x: [*c]c_longdouble, __payload: c_longdouble) c_int;
pub extern fn setpayloadsigf64x(__x: [*c]c_longdouble, __payload: c_longdouble) c_int;
pub extern fn fadd(__x: f64, __y: f64) f32;
pub extern fn fdiv(__x: f64, __y: f64) f32;
pub extern fn ffma(__x: f64, __y: f64, __z: f64) f32;
pub extern fn fmul(__x: f64, __y: f64) f32;
pub extern fn fsqrt(__x: f64) f32;
pub extern fn fsub(__x: f64, __y: f64) f32;
pub extern fn faddl(__x: c_longdouble, __y: c_longdouble) f32;
pub extern fn fdivl(__x: c_longdouble, __y: c_longdouble) f32;
pub extern fn ffmal(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) f32;
pub extern fn fmull(__x: c_longdouble, __y: c_longdouble) f32;
pub extern fn fsqrtl(__x: c_longdouble) f32;
pub extern fn fsubl(__x: c_longdouble, __y: c_longdouble) f32;
pub extern fn daddl(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn ddivl(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn dfmal(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) f64;
pub extern fn dmull(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn dsqrtl(__x: c_longdouble) f64;
pub extern fn dsubl(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f32addf32x(__x: f64, __y: f64) f32;
pub extern fn f32divf32x(__x: f64, __y: f64) f32;
pub extern fn f32fmaf32x(__x: f64, __y: f64, __z: f64) f32;
pub extern fn f32mulf32x(__x: f64, __y: f64) f32;
pub extern fn f32sqrtf32x(__x: f64) f32;
pub extern fn f32subf32x(__x: f64, __y: f64) f32;
pub extern fn f32addf64(__x: f64, __y: f64) f32;
pub extern fn f32divf64(__x: f64, __y: f64) f32;
pub extern fn f32fmaf64(__x: f64, __y: f64, __z: f64) f32;
pub extern fn f32mulf64(__x: f64, __y: f64) f32;
pub extern fn f32sqrtf64(__x: f64) f32;
pub extern fn f32subf64(__x: f64, __y: f64) f32;
pub extern fn f32addf64x(__x: c_longdouble, __y: c_longdouble) f32;
pub extern fn f32divf64x(__x: c_longdouble, __y: c_longdouble) f32;
pub extern fn f32fmaf64x(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) f32;
pub extern fn f32mulf64x(__x: c_longdouble, __y: c_longdouble) f32;
pub extern fn f32sqrtf64x(__x: c_longdouble) f32;
pub extern fn f32subf64x(__x: c_longdouble, __y: c_longdouble) f32;
pub extern fn f32addf128(__x: f128, __y: f128) f32;
pub extern fn f32divf128(__x: f128, __y: f128) f32;
pub extern fn f32fmaf128(__x: f128, __y: f128, __z: f128) f32;
pub extern fn f32mulf128(__x: f128, __y: f128) f32;
pub extern fn f32sqrtf128(__x: f128) f32;
pub extern fn f32subf128(__x: f128, __y: f128) f32;
pub extern fn f32xaddf64(__x: f64, __y: f64) f64;
pub extern fn f32xdivf64(__x: f64, __y: f64) f64;
pub extern fn f32xfmaf64(__x: f64, __y: f64, __z: f64) f64;
pub extern fn f32xmulf64(__x: f64, __y: f64) f64;
pub extern fn f32xsqrtf64(__x: f64) f64;
pub extern fn f32xsubf64(__x: f64, __y: f64) f64;
pub extern fn f32xaddf64x(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f32xdivf64x(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f32xfmaf64x(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) f64;
pub extern fn f32xmulf64x(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f32xsqrtf64x(__x: c_longdouble) f64;
pub extern fn f32xsubf64x(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f32xaddf128(__x: f128, __y: f128) f64;
pub extern fn f32xdivf128(__x: f128, __y: f128) f64;
pub extern fn f32xfmaf128(__x: f128, __y: f128, __z: f128) f64;
pub extern fn f32xmulf128(__x: f128, __y: f128) f64;
pub extern fn f32xsqrtf128(__x: f128) f64;
pub extern fn f32xsubf128(__x: f128, __y: f128) f64;
pub extern fn f64addf64x(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f64divf64x(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f64fmaf64x(__x: c_longdouble, __y: c_longdouble, __z: c_longdouble) f64;
pub extern fn f64mulf64x(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f64sqrtf64x(__x: c_longdouble) f64;
pub extern fn f64subf64x(__x: c_longdouble, __y: c_longdouble) f64;
pub extern fn f64addf128(__x: f128, __y: f128) f64;
pub extern fn f64divf128(__x: f128, __y: f128) f64;
pub extern fn f64fmaf128(__x: f128, __y: f128, __z: f128) f64;
pub extern fn f64mulf128(__x: f128, __y: f128) f64;
pub extern fn f64sqrtf128(__x: f128) f64;
pub extern fn f64subf128(__x: f128, __y: f128) f64;
pub extern fn f64xaddf128(__x: f128, __y: f128) c_longdouble;
pub extern fn f64xdivf128(__x: f128, __y: f128) c_longdouble;
pub extern fn f64xfmaf128(__x: f128, __y: f128, __z: f128) c_longdouble;
pub extern fn f64xmulf128(__x: f128, __y: f128) c_longdouble;
pub extern fn f64xsqrtf128(__x: f128) c_longdouble;
pub extern fn f64xsubf128(__x: f128, __y: f128) c_longdouble;
pub extern var signgam: c_int;
pub const FP_NAN: c_int = 0;
pub const FP_INFINITE: c_int = 1;
pub const FP_ZERO: c_int = 2;
pub const FP_SUBNORMAL: c_int = 3;
pub const FP_NORMAL: c_int = 4;
const enum_unnamed_2 = c_uint;
pub extern fn __iscanonicall(__x: c_longdouble) c_int;
pub const struct___va_list_tag_3 = extern struct {
    unnamed_0: c_uint = 0,
    unnamed_1: c_uint = 0,
    unnamed_2: ?*anyopaque = null,
    unnamed_3: ?*anyopaque = null,
};
pub const __builtin_va_list = [1]struct___va_list_tag_3;
pub const va_list = __builtin_va_list;
pub const __gnuc_va_list = __builtin_va_list;
pub const ptrdiff_t = c_long;
pub const wchar_t = c_int;
pub const max_align_t = extern struct {
    __aro_max_align_ll: c_longlong = 0,
    __aro_max_align_ld: c_longdouble = 0,
};
pub const wint_t = c_uint;
const union_unnamed_4 = extern union {
    __wch: c_uint,
    __wchb: [4]u8,
};
pub const __mbstate_t = extern struct {
    __count: c_int = 0,
    __value: union_unnamed_4 = @import("std").mem.zeroes(union_unnamed_4),
    pub const mbsinit = __root.mbsinit;
};
pub const mbstate_t = __mbstate_t;
pub const struct__IO_marker = opaque {};
pub const _IO_lock_t = anyopaque;
pub const struct__IO_codecvt = opaque {};
pub const struct__IO_wide_data = opaque {};
pub const struct__IO_FILE = extern struct {
    _flags: c_int = 0,
    _IO_read_ptr: [*c]u8 = null,
    _IO_read_end: [*c]u8 = null,
    _IO_read_base: [*c]u8 = null,
    _IO_write_base: [*c]u8 = null,
    _IO_write_ptr: [*c]u8 = null,
    _IO_write_end: [*c]u8 = null,
    _IO_buf_base: [*c]u8 = null,
    _IO_buf_end: [*c]u8 = null,
    _IO_save_base: [*c]u8 = null,
    _IO_backup_base: [*c]u8 = null,
    _IO_save_end: [*c]u8 = null,
    _markers: ?*struct__IO_marker = null,
    _chain: [*c]struct__IO_FILE = null,
    _fileno: c_int = 0,
    _flags2: c_int = 0,
    _old_offset: __off_t = 0,
    _cur_column: c_ushort = 0,
    _vtable_offset: i8 = 0,
    _shortbuf: [1]u8 = @import("std").mem.zeroes([1]u8),
    _lock: ?*_IO_lock_t = null,
    _offset: __off64_t = 0,
    _codecvt: ?*struct__IO_codecvt = null,
    _wide_data: ?*struct__IO_wide_data = null,
    _freeres_list: [*c]struct__IO_FILE = null,
    _freeres_buf: ?*anyopaque = null,
    __pad5: usize = 0,
    _mode: c_int = 0,
    _unused2: [20]u8 = @import("std").mem.zeroes([20]u8),
    pub const fwide = __root.fwide;
    pub const fwprintf = __root.fwprintf;
    pub const vfwprintf = __root.vfwprintf;
    pub const fwscanf = __root.fwscanf;
    pub const vfwscanf = __root.vfwscanf;
    pub const fgetwc = __root.fgetwc;
    pub const getwc = __root.getwc;
    pub const getwc_unlocked = __root.getwc_unlocked;
    pub const fgetwc_unlocked = __root.fgetwc_unlocked;
    pub const fclose = __root.fclose;
    pub const fflush = __root.fflush;
    pub const fflush_unlocked = __root.fflush_unlocked;
    pub const setbuf = __root.setbuf;
    pub const setvbuf = __root.setvbuf;
    pub const setbuffer = __root.setbuffer;
    pub const setlinebuf = __root.setlinebuf;
    pub const fprintf = __root.fprintf;
    pub const vfprintf = __root.vfprintf;
    pub const fscanf = __root.fscanf;
    pub const vfscanf = __root.vfscanf;
    pub const fgetc = __root.fgetc;
    pub const getc = __root.getc;
    pub const getc_unlocked = __root.getc_unlocked;
    pub const fgetc_unlocked = __root.fgetc_unlocked;
    pub const getw = __root.getw;
    pub const fseek = __root.fseek;
    pub const ftell = __root.ftell;
    pub const rewind = __root.rewind;
    pub const fseeko = __root.fseeko;
    pub const ftello = __root.ftello;
    pub const fgetpos = __root.fgetpos;
    pub const fsetpos = __root.fsetpos;
    pub const fseeko64 = __root.fseeko64;
    pub const ftello64 = __root.ftello64;
    pub const fgetpos64 = __root.fgetpos64;
    pub const fsetpos64 = __root.fsetpos64;
    pub const clearerr = __root.clearerr;
    pub const feof = __root.feof;
    pub const ferror = __root.ferror;
    pub const clearerr_unlocked = __root.clearerr_unlocked;
    pub const feof_unlocked = __root.feof_unlocked;
    pub const ferror_unlocked = __root.ferror_unlocked;
    pub const fileno = __root.fileno;
    pub const fileno_unlocked = __root.fileno_unlocked;
    pub const pclose = __root.pclose;
    pub const flockfile = __root.flockfile;
    pub const ftrylockfile = __root.ftrylockfile;
    pub const funlockfile = __root.funlockfile;
    pub const __uflow = __root.__uflow;
    pub const __overflow = __root.__overflow;
    pub const PyRun_AnyFileExFlags = __root.PyRun_AnyFileExFlags;
    pub const PyRun_SimpleFileExFlags = __root.PyRun_SimpleFileExFlags;
    pub const PyRun_InteractiveOneFlags = __root.PyRun_InteractiveOneFlags;
    pub const PyRun_InteractiveOneObject = __root.PyRun_InteractiveOneObject;
    pub const PyRun_InteractiveLoopFlags = __root.PyRun_InteractiveLoopFlags;
    pub const PyRun_FileExFlags = __root.PyRun_FileExFlags;
    pub const PyRun_AnyFile = __root.PyRun_AnyFile;
    pub const PyRun_AnyFileEx = __root.PyRun_AnyFileEx;
    pub const PyRun_AnyFileFlags = __root.PyRun_AnyFileFlags;
    pub const PyRun_SimpleFile = __root.PyRun_SimpleFile;
    pub const PyRun_SimpleFileEx = __root.PyRun_SimpleFileEx;
    pub const PyRun_InteractiveOne = __root.PyRun_InteractiveOne;
    pub const PyRun_InteractiveLoop = __root.PyRun_InteractiveLoop;
    pub const PyRun_File = __root.PyRun_File;
    pub const PyRun_FileEx = __root.PyRun_FileEx;
    pub const PyRun_FileFlags = __root.PyRun_FileFlags;
    pub const PyOS_Readline = __root.PyOS_Readline;
    pub const Py_FdIsInteractive = __root.Py_FdIsInteractive;
    pub const Py_fclose = __root.Py_fclose;
    pub const unlocked = __root.getwc_unlocked;
    pub const uflow = __root.__uflow;
    pub const overflow = __root.__overflow;
    pub const AnyFileExFlags = __root.PyRun_AnyFileExFlags;
    pub const SimpleFileExFlags = __root.PyRun_SimpleFileExFlags;
    pub const InteractiveOneFlags = __root.PyRun_InteractiveOneFlags;
    pub const InteractiveOneObject = __root.PyRun_InteractiveOneObject;
    pub const InteractiveLoopFlags = __root.PyRun_InteractiveLoopFlags;
    pub const FileExFlags = __root.PyRun_FileExFlags;
    pub const AnyFile = __root.PyRun_AnyFile;
    pub const AnyFileEx = __root.PyRun_AnyFileEx;
    pub const AnyFileFlags = __root.PyRun_AnyFileFlags;
    pub const SimpleFile = __root.PyRun_SimpleFile;
    pub const SimpleFileEx = __root.PyRun_SimpleFileEx;
    pub const InteractiveOne = __root.PyRun_InteractiveOne;
    pub const InteractiveLoop = __root.PyRun_InteractiveLoop;
    pub const File = __root.PyRun_File;
    pub const FileEx = __root.PyRun_FileEx;
    pub const FileFlags = __root.PyRun_FileFlags;
    pub const Readline = __root.PyOS_Readline;
    pub const FdIsInteractive = __root.Py_FdIsInteractive;
};
pub const __FILE = struct__IO_FILE;
pub const FILE = struct__IO_FILE;
pub const struct___locale_data_5 = opaque {};
pub const struct___locale_struct = extern struct {
    __locales: [13]?*struct___locale_data_5 = @import("std").mem.zeroes([13]?*struct___locale_data_5),
    __ctype_b: [*c]const c_ushort = null,
    __ctype_tolower: [*c]const c_int = null,
    __ctype_toupper: [*c]const c_int = null,
    __names: [13][*c]const u8 = @import("std").mem.zeroes([13][*c]const u8),
};
pub const __locale_t = [*c]struct___locale_struct;
pub const locale_t = __locale_t;
pub const struct_tm = extern struct {
    tm_sec: c_int = 0,
    tm_min: c_int = 0,
    tm_hour: c_int = 0,
    tm_mday: c_int = 0,
    tm_mon: c_int = 0,
    tm_year: c_int = 0,
    tm_wday: c_int = 0,
    tm_yday: c_int = 0,
    tm_isdst: c_int = 0,
    tm_gmtoff: c_long = 0,
    tm_zone: [*c]const u8 = null,
    pub const mktime = __root.mktime;
    pub const asctime = __root.asctime;
    pub const asctime_r = __root.asctime_r;
    pub const timegm = __root.timegm;
    pub const timelocal = __root.timelocal;
    pub const r = __root.asctime_r;
};
pub extern fn wcscpy(noalias __dest: [*c]wchar_t, noalias __src: [*c]const wchar_t) [*c]wchar_t;
pub extern fn wcsncpy(noalias __dest: [*c]wchar_t, noalias __src: [*c]const wchar_t, __n: usize) [*c]wchar_t;
pub extern fn wcslcpy(noalias __dest: [*c]wchar_t, noalias __src: [*c]const wchar_t, __n: usize) usize;
pub extern fn wcslcat(noalias __dest: [*c]wchar_t, noalias __src: [*c]const wchar_t, __n: usize) usize;
pub extern fn wcscat(noalias __dest: [*c]wchar_t, noalias __src: [*c]const wchar_t) [*c]wchar_t;
pub extern fn wcsncat(noalias __dest: [*c]wchar_t, noalias __src: [*c]const wchar_t, __n: usize) [*c]wchar_t;
pub extern fn wcscmp(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t) c_int;
pub extern fn wcsncmp(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t, __n: usize) c_int;
pub extern fn wcscasecmp(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t) c_int;
pub extern fn wcsncasecmp(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t, __n: usize) c_int;
pub extern fn wcscasecmp_l(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t, __loc: locale_t) c_int;
pub extern fn wcsncasecmp_l(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t, __n: usize, __loc: locale_t) c_int;
pub extern fn wcscoll(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t) c_int;
pub extern fn wcsxfrm(noalias __s1: [*c]wchar_t, noalias __s2: [*c]const wchar_t, __n: usize) usize;
pub extern fn wcscoll_l(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t, __loc: locale_t) c_int;
pub extern fn wcsxfrm_l(__s1: [*c]wchar_t, __s2: [*c]const wchar_t, __n: usize, __loc: locale_t) usize;
pub extern fn wcsdup(__s: [*c]const wchar_t) [*c]wchar_t;
pub extern fn wcschr(__wcs: [*c]const wchar_t, __wc: wchar_t) [*c]wchar_t;
pub extern fn wcsrchr(__wcs: [*c]const wchar_t, __wc: wchar_t) [*c]wchar_t;
pub extern fn wcschrnul(__s: [*c]const wchar_t, __wc: wchar_t) [*c]wchar_t;
pub extern fn wcscspn(__wcs: [*c]const wchar_t, __reject: [*c]const wchar_t) usize;
pub extern fn wcsspn(__wcs: [*c]const wchar_t, __accept: [*c]const wchar_t) usize;
pub extern fn wcspbrk(__wcs: [*c]const wchar_t, __accept: [*c]const wchar_t) [*c]wchar_t;
pub extern fn wcsstr(__haystack: [*c]const wchar_t, __needle: [*c]const wchar_t) [*c]wchar_t;
pub extern fn wcstok(noalias __s: [*c]wchar_t, noalias __delim: [*c]const wchar_t, noalias __ptr: [*c][*c]wchar_t) [*c]wchar_t;
pub extern fn wcslen(__s: [*c]const wchar_t) usize;
pub extern fn wcswcs(__haystack: [*c]const wchar_t, __needle: [*c]const wchar_t) [*c]wchar_t;
pub extern fn wcsnlen(__s: [*c]const wchar_t, __maxlen: usize) usize;
pub extern fn wmemchr(__s: [*c]const wchar_t, __c: wchar_t, __n: usize) [*c]wchar_t;
pub extern fn wmemcmp(__s1: [*c]const wchar_t, __s2: [*c]const wchar_t, __n: usize) c_int;
pub extern fn wmemcpy(noalias __s1: [*c]wchar_t, noalias __s2: [*c]const wchar_t, __n: usize) [*c]wchar_t;
pub extern fn wmemmove(__s1: [*c]wchar_t, __s2: [*c]const wchar_t, __n: usize) [*c]wchar_t;
pub extern fn wmemset(__s: [*c]wchar_t, __c: wchar_t, __n: usize) [*c]wchar_t;
pub extern fn wmempcpy(noalias __s1: [*c]wchar_t, noalias __s2: [*c]const wchar_t, __n: usize) [*c]wchar_t;
pub fn btowc(arg___c: c_int) callconv(.c) wint_t {
    var __c = arg___c;
    _ = &__c;
    const extern_local___btowc_alias = struct {
        extern fn __btowc_alias(__c: c_int) wint_t;
    };
    _ = &extern_local___btowc_alias;
    return if (((__builtin.constant_p(__c) != 0) and (__c >= @as(c_int, '\x00'))) and (__c <= @as(c_int, '\x7f'))) @as(wint_t, @bitCast(@as(c_int, __c))) else __btowc_alias(__c);
}
pub fn wctob(arg___wc: wint_t) callconv(.c) c_int {
    var __wc = arg___wc;
    _ = &__wc;
    const extern_local___wctob_alias = struct {
        extern fn __wctob_alias(__c: wint_t) c_int;
    };
    _ = &extern_local___wctob_alias;
    return if (((__builtin.constant_p(__wc) != 0) and (__wc >= @as(wint_t, '\u{0}'))) and (__wc <= @as(wint_t, '\u{7f}'))) @as(c_int, @bitCast(@as(c_uint, @truncate(__wc)))) else __wctob_alias(__wc);
}
pub extern fn mbsinit(__ps: [*c]const mbstate_t) c_int;
pub extern fn mbrtowc(noalias __pwc: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize, noalias __p: [*c]mbstate_t) usize;
pub extern fn wcrtomb(noalias __s: [*c]u8, __wc: wchar_t, noalias __ps: [*c]mbstate_t) usize;
pub extern fn __mbrlen(noalias __s: [*c]const u8, __n: usize, noalias __ps: [*c]mbstate_t) usize;
pub fn mbrlen(noalias arg___s: [*c]const u8, arg___n: usize, noalias arg___ps: [*c]mbstate_t) callconv(.c) usize {
    var __s = arg___s;
    _ = &__s;
    var __n = arg___n;
    _ = &__n;
    var __ps = arg___ps;
    _ = &__ps;
    return if (@as(?*anyopaque, @ptrCast(@alignCast(__ps))) != @as(?*anyopaque, null)) mbrtowc(null, __s, __n, __ps) else __mbrlen(__s, __n, null);
}
pub extern fn __btowc_alias(__c: c_int) wint_t;
pub extern fn __wctob_alias(__c: wint_t) c_int;
pub extern fn mbsrtowcs(noalias __dst: [*c]wchar_t, noalias __src: [*c][*c]const u8, __len: usize, noalias __ps: [*c]mbstate_t) usize;
pub extern fn wcsrtombs(noalias __dst: [*c]u8, noalias __src: [*c][*c]const wchar_t, __len: usize, noalias __ps: [*c]mbstate_t) usize;
pub extern fn mbsnrtowcs(noalias __dst: [*c]wchar_t, noalias __src: [*c][*c]const u8, __nmc: usize, __len: usize, noalias __ps: [*c]mbstate_t) usize;
pub extern fn wcsnrtombs(noalias __dst: [*c]u8, noalias __src: [*c][*c]const wchar_t, __nwc: usize, __len: usize, noalias __ps: [*c]mbstate_t) usize;
pub extern fn wcwidth(__c: wchar_t) c_int;
pub extern fn wcswidth(__s: [*c]const wchar_t, __n: usize) c_int;
pub extern fn wcstod(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t) f64;
pub extern fn wcstof(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t) f32;
pub extern fn wcstold(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t) c_longdouble;
pub extern fn wcstof32(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t) f32;
pub extern fn wcstof64(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t) f64;
pub extern fn wcstof128(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t) f128;
pub extern fn wcstof32x(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t) f64;
pub extern fn wcstof64x(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t) c_longdouble;
pub extern fn wcstol(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int) c_long;
pub extern fn wcstoul(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int) c_ulong;
pub extern fn wcstoll(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int) c_longlong;
pub extern fn wcstoull(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int) c_ulonglong;
pub extern fn wcstoq(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int) c_longlong;
pub extern fn wcstouq(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int) c_ulonglong;
pub extern fn wcstol_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int, __loc: locale_t) c_long;
pub extern fn wcstoul_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int, __loc: locale_t) c_ulong;
pub extern fn wcstoll_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int, __loc: locale_t) c_longlong;
pub extern fn wcstoull_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __base: c_int, __loc: locale_t) c_ulonglong;
pub extern fn wcstod_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __loc: locale_t) f64;
pub extern fn wcstof_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __loc: locale_t) f32;
pub extern fn wcstold_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __loc: locale_t) c_longdouble;
pub extern fn wcstof32_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __loc: locale_t) f32;
pub extern fn wcstof64_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __loc: locale_t) f64;
pub extern fn wcstof128_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __loc: locale_t) f128;
pub extern fn wcstof32x_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __loc: locale_t) f64;
pub extern fn wcstof64x_l(noalias __nptr: [*c]const wchar_t, noalias __endptr: [*c][*c]wchar_t, __loc: locale_t) c_longdouble;
pub extern fn wcpcpy(noalias __dest: [*c]wchar_t, noalias __src: [*c]const wchar_t) [*c]wchar_t;
pub extern fn wcpncpy(noalias __dest: [*c]wchar_t, noalias __src: [*c]const wchar_t, __n: usize) [*c]wchar_t;
pub extern fn open_wmemstream(__bufloc: [*c][*c]wchar_t, __sizeloc: [*c]usize) [*c]__FILE;
pub extern fn fwide(__fp: [*c]__FILE, __mode: c_int) c_int;
pub extern fn fwprintf(noalias __stream: [*c]__FILE, noalias __format: [*c]const wchar_t, ...) c_int;
pub extern fn wprintf(noalias __format: [*c]const wchar_t, ...) c_int;
pub extern fn swprintf(noalias __s: [*c]wchar_t, __n: usize, noalias __format: [*c]const wchar_t, ...) c_int;
pub extern fn vfwprintf(noalias __s: [*c]__FILE, noalias __format: [*c]const wchar_t, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn vwprintf(noalias __format: [*c]const wchar_t, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn vswprintf(noalias __s: [*c]wchar_t, __n: usize, noalias __format: [*c]const wchar_t, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn fwscanf(noalias __stream: [*c]__FILE, noalias __format: [*c]const wchar_t, ...) c_int;
pub extern fn wscanf(noalias __format: [*c]const wchar_t, ...) c_int;
pub extern fn swscanf(noalias __s: [*c]const wchar_t, noalias __format: [*c]const wchar_t, ...) c_int;
pub extern fn vfwscanf(noalias __s: [*c]__FILE, noalias __format: [*c]const wchar_t, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn vwscanf(noalias __format: [*c]const wchar_t, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn vswscanf(noalias __s: [*c]const wchar_t, noalias __format: [*c]const wchar_t, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn fgetwc(__stream: [*c]__FILE) wint_t;
pub extern fn getwc(__stream: [*c]__FILE) wint_t;
pub extern fn getwchar() wint_t;
pub extern fn fputwc(__wc: wchar_t, __stream: [*c]__FILE) wint_t;
pub extern fn putwc(__wc: wchar_t, __stream: [*c]__FILE) wint_t;
pub extern fn putwchar(__wc: wchar_t) wint_t;
pub extern fn fgetws(noalias __ws: [*c]wchar_t, __n: c_int, noalias __stream: [*c]__FILE) [*c]wchar_t;
pub extern fn fputws(noalias __ws: [*c]const wchar_t, noalias __stream: [*c]__FILE) c_int;
pub extern fn ungetwc(__wc: wint_t, __stream: [*c]__FILE) wint_t;
pub extern fn getwc_unlocked(__stream: [*c]__FILE) wint_t;
pub extern fn getwchar_unlocked() wint_t;
pub extern fn fgetwc_unlocked(__stream: [*c]__FILE) wint_t;
pub extern fn fputwc_unlocked(__wc: wchar_t, __stream: [*c]__FILE) wint_t;
pub extern fn putwc_unlocked(__wc: wchar_t, __stream: [*c]__FILE) wint_t;
pub extern fn putwchar_unlocked(__wc: wchar_t) wint_t;
pub extern fn fgetws_unlocked(noalias __ws: [*c]wchar_t, __n: c_int, noalias __stream: [*c]__FILE) [*c]wchar_t;
pub extern fn fputws_unlocked(noalias __ws: [*c]const wchar_t, noalias __stream: [*c]__FILE) c_int;
pub extern fn wcsftime(noalias __s: [*c]wchar_t, __maxsize: usize, noalias __format: [*c]const wchar_t, noalias __tp: [*c]const struct_tm) usize;
pub extern fn wcsftime_l(noalias __s: [*c]wchar_t, __maxsize: usize, noalias __format: [*c]const wchar_t, noalias __tp: [*c]const struct_tm, __loc: locale_t) usize;
pub const u_char = __u_char;
pub const u_short = __u_short;
pub const u_int = __u_int;
pub const u_long = __u_long;
pub const quad_t = __quad_t;
pub const u_quad_t = __u_quad_t;
pub const fsid_t = __fsid_t;
pub const loff_t = __loff_t;
pub const ino_t = __ino64_t;
pub const ino64_t = __ino64_t;
pub const dev_t = __dev_t;
pub const gid_t = __gid_t;
pub const mode_t = __mode_t;
pub const nlink_t = __nlink_t;
pub const uid_t = __uid_t;
pub const off_t = __off64_t;
pub const off64_t = __off64_t;
pub const pid_t = __pid_t;
pub const id_t = __id_t;
pub const daddr_t = __daddr_t;
pub const caddr_t = __caddr_t;
pub const key_t = __key_t;
pub const clock_t = __clock_t;
pub const clockid_t = __clockid_t;
pub const time_t = __time_t;
pub const timer_t = __timer_t;
pub const useconds_t = __useconds_t;
pub const suseconds_t = __suseconds_t;
pub const ulong = c_ulong;
pub const ushort = c_ushort;
pub const uint = c_uint;
pub const u_int8_t = __uint8_t;
pub const u_int16_t = __uint16_t;
pub const u_int32_t = __uint32_t;
pub const u_int64_t = __uint64_t;
pub const register_t = c_int;
pub fn __bswap_16(arg___bsx: __uint16_t) callconv(.c) __uint16_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @byteSwap(@as(__uint16_t, __bsx));
}
pub fn __bswap_32(arg___bsx: __uint32_t) callconv(.c) __uint32_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @bitCast(@as(c_int, @byteSwap(@as(c_int, @bitCast(@as(c_uint, @truncate(__bsx)))))));
}
pub fn __bswap_64(arg___bsx: __uint64_t) callconv(.c) __uint64_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @bitCast(@as(c_long, @byteSwap(@as(c_long, @bitCast(@as(c_ulong, @truncate(__bsx)))))));
}
pub fn __uint16_identity(arg___x: __uint16_t) callconv(.c) __uint16_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub fn __uint32_identity(arg___x: __uint32_t) callconv(.c) __uint32_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub fn __uint64_identity(arg___x: __uint64_t) callconv(.c) __uint64_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub const __sigset_t = extern struct {
    __val: [16]c_ulong = @import("std").mem.zeroes([16]c_ulong),
};
pub const sigset_t = __sigset_t;
pub const struct_timeval = extern struct {
    tv_sec: __time_t = 0,
    tv_usec: __suseconds_t = 0,
};
pub const struct_timespec = extern struct {
    tv_sec: __time_t = 0,
    tv_nsec: __syscall_slong_t = 0,
    pub const nanosleep = __root.nanosleep;
    pub const timespec_get = __root.timespec_get;
    pub const timespec_getres = __root.timespec_getres;
    pub const get = __root.timespec_get;
    pub const getres = __root.timespec_getres;
};
pub const __fd_mask = c_long;
pub const fd_set = extern struct {
    fds_bits: [16]__fd_mask = @import("std").mem.zeroes([16]__fd_mask),
};
pub const fd_mask = __fd_mask;
pub extern fn select(__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]struct_timeval) c_int;
pub extern fn pselect(__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]const struct_timespec, noalias __sigmask: [*c]const __sigset_t) c_int;
pub const blksize_t = __blksize_t;
pub const blkcnt_t = __blkcnt64_t;
pub const fsblkcnt_t = __fsblkcnt64_t;
pub const fsfilcnt_t = __fsfilcnt64_t;
pub const blkcnt64_t = __blkcnt64_t;
pub const fsblkcnt64_t = __fsblkcnt64_t;
pub const fsfilcnt64_t = __fsfilcnt64_t;
const struct_unnamed_6 = extern struct {
    __low: c_uint = 0,
    __high: c_uint = 0,
};
pub const __atomic_wide_counter = extern union {
    __value64: c_ulonglong,
    __value32: struct_unnamed_6,
};
pub const struct___pthread_internal_list = extern struct {
    __prev: [*c]struct___pthread_internal_list = null,
    __next: [*c]struct___pthread_internal_list = null,
};
pub const __pthread_list_t = struct___pthread_internal_list;
pub const struct___pthread_internal_slist = extern struct {
    __next: [*c]struct___pthread_internal_slist = null,
};
pub const __pthread_slist_t = struct___pthread_internal_slist;
pub const struct___pthread_mutex_s = extern struct {
    __lock: c_int = 0,
    __count: c_uint = 0,
    __owner: c_int = 0,
    __nusers: c_uint = 0,
    __kind: c_int = 0,
    __spins: c_short = 0,
    __elision: c_short = 0,
    __list: __pthread_list_t = @import("std").mem.zeroes(__pthread_list_t),
};
pub const struct___pthread_rwlock_arch_t = extern struct {
    __readers: c_uint = 0,
    __writers: c_uint = 0,
    __wrphase_futex: c_uint = 0,
    __writers_futex: c_uint = 0,
    __pad3: c_uint = 0,
    __pad4: c_uint = 0,
    __cur_writer: c_int = 0,
    __shared: c_int = 0,
    __rwelision: i8 = 0,
    __pad1: [7]u8 = @import("std").mem.zeroes([7]u8),
    __pad2: c_ulong = 0,
    __flags: c_uint = 0,
};
pub const struct___pthread_cond_s = extern struct {
    __wseq: __atomic_wide_counter = @import("std").mem.zeroes(__atomic_wide_counter),
    __g1_start: __atomic_wide_counter = @import("std").mem.zeroes(__atomic_wide_counter),
    __g_refs: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
    __g_size: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
    __g1_orig_size: c_uint = 0,
    __wrefs: c_uint = 0,
    __g_signals: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
};
pub const __tss_t = c_uint;
pub const __thrd_t = c_ulong;
pub const __once_flag = extern struct {
    __data: c_int = 0,
};
pub const pthread_t = c_ulong;
pub const pthread_mutexattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
    pub const pthread_mutexattr_init = __root.pthread_mutexattr_init;
    pub const pthread_mutexattr_destroy = __root.pthread_mutexattr_destroy;
    pub const pthread_mutexattr_getpshared = __root.pthread_mutexattr_getpshared;
    pub const pthread_mutexattr_setpshared = __root.pthread_mutexattr_setpshared;
    pub const pthread_mutexattr_gettype = __root.pthread_mutexattr_gettype;
    pub const pthread_mutexattr_settype = __root.pthread_mutexattr_settype;
    pub const pthread_mutexattr_getprotocol = __root.pthread_mutexattr_getprotocol;
    pub const pthread_mutexattr_setprotocol = __root.pthread_mutexattr_setprotocol;
    pub const pthread_mutexattr_getprioceiling = __root.pthread_mutexattr_getprioceiling;
    pub const pthread_mutexattr_setprioceiling = __root.pthread_mutexattr_setprioceiling;
    pub const pthread_mutexattr_getrobust = __root.pthread_mutexattr_getrobust;
    pub const pthread_mutexattr_getrobust_np = __root.pthread_mutexattr_getrobust_np;
    pub const pthread_mutexattr_setrobust = __root.pthread_mutexattr_setrobust;
    pub const pthread_mutexattr_setrobust_np = __root.pthread_mutexattr_setrobust_np;
    pub const init = __root.pthread_mutexattr_init;
    pub const destroy = __root.pthread_mutexattr_destroy;
    pub const getpshared = __root.pthread_mutexattr_getpshared;
    pub const setpshared = __root.pthread_mutexattr_setpshared;
    pub const gettype = __root.pthread_mutexattr_gettype;
    pub const settype = __root.pthread_mutexattr_settype;
    pub const getprotocol = __root.pthread_mutexattr_getprotocol;
    pub const setprotocol = __root.pthread_mutexattr_setprotocol;
    pub const getprioceiling = __root.pthread_mutexattr_getprioceiling;
    pub const setprioceiling = __root.pthread_mutexattr_setprioceiling;
    pub const getrobust = __root.pthread_mutexattr_getrobust;
    pub const np = __root.pthread_mutexattr_getrobust_np;
    pub const setrobust = __root.pthread_mutexattr_setrobust;
};
pub const pthread_condattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
    pub const pthread_condattr_init = __root.pthread_condattr_init;
    pub const pthread_condattr_destroy = __root.pthread_condattr_destroy;
    pub const pthread_condattr_getpshared = __root.pthread_condattr_getpshared;
    pub const pthread_condattr_setpshared = __root.pthread_condattr_setpshared;
    pub const pthread_condattr_getclock = __root.pthread_condattr_getclock;
    pub const pthread_condattr_setclock = __root.pthread_condattr_setclock;
    pub const init = __root.pthread_condattr_init;
    pub const destroy = __root.pthread_condattr_destroy;
    pub const getpshared = __root.pthread_condattr_getpshared;
    pub const setpshared = __root.pthread_condattr_setpshared;
    pub const getclock = __root.pthread_condattr_getclock;
    pub const setclock = __root.pthread_condattr_setclock;
};
pub const pthread_key_t = c_uint;
pub const pthread_once_t = c_int;
pub const union_pthread_attr_t = extern union {
    __size: [56]u8,
    __align: c_long,
    pub const pthread_attr_init = __root.pthread_attr_init;
    pub const pthread_attr_destroy = __root.pthread_attr_destroy;
    pub const pthread_attr_getdetachstate = __root.pthread_attr_getdetachstate;
    pub const pthread_attr_setdetachstate = __root.pthread_attr_setdetachstate;
    pub const pthread_attr_getguardsize = __root.pthread_attr_getguardsize;
    pub const pthread_attr_setguardsize = __root.pthread_attr_setguardsize;
    pub const pthread_attr_getschedparam = __root.pthread_attr_getschedparam;
    pub const pthread_attr_setschedparam = __root.pthread_attr_setschedparam;
    pub const pthread_attr_getschedpolicy = __root.pthread_attr_getschedpolicy;
    pub const pthread_attr_setschedpolicy = __root.pthread_attr_setschedpolicy;
    pub const pthread_attr_getinheritsched = __root.pthread_attr_getinheritsched;
    pub const pthread_attr_setinheritsched = __root.pthread_attr_setinheritsched;
    pub const pthread_attr_getscope = __root.pthread_attr_getscope;
    pub const pthread_attr_setscope = __root.pthread_attr_setscope;
    pub const pthread_attr_getstackaddr = __root.pthread_attr_getstackaddr;
    pub const pthread_attr_setstackaddr = __root.pthread_attr_setstackaddr;
    pub const pthread_attr_getstacksize = __root.pthread_attr_getstacksize;
    pub const pthread_attr_setstacksize = __root.pthread_attr_setstacksize;
    pub const pthread_attr_getstack = __root.pthread_attr_getstack;
    pub const pthread_attr_setstack = __root.pthread_attr_setstack;
    pub const pthread_attr_setaffinity_np = __root.pthread_attr_setaffinity_np;
    pub const pthread_attr_getaffinity_np = __root.pthread_attr_getaffinity_np;
    pub const pthread_getattr_default_np = __root.pthread_getattr_default_np;
    pub const pthread_attr_setsigmask_np = __root.pthread_attr_setsigmask_np;
    pub const pthread_attr_getsigmask_np = __root.pthread_attr_getsigmask_np;
    pub const pthread_setattr_default_np = __root.pthread_setattr_default_np;
    pub const init = __root.pthread_attr_init;
    pub const destroy = __root.pthread_attr_destroy;
    pub const getdetachstate = __root.pthread_attr_getdetachstate;
    pub const setdetachstate = __root.pthread_attr_setdetachstate;
    pub const getguardsize = __root.pthread_attr_getguardsize;
    pub const setguardsize = __root.pthread_attr_setguardsize;
    pub const getschedparam = __root.pthread_attr_getschedparam;
    pub const setschedparam = __root.pthread_attr_setschedparam;
    pub const getschedpolicy = __root.pthread_attr_getschedpolicy;
    pub const setschedpolicy = __root.pthread_attr_setschedpolicy;
    pub const getinheritsched = __root.pthread_attr_getinheritsched;
    pub const setinheritsched = __root.pthread_attr_setinheritsched;
    pub const getscope = __root.pthread_attr_getscope;
    pub const setscope = __root.pthread_attr_setscope;
    pub const getstackaddr = __root.pthread_attr_getstackaddr;
    pub const setstackaddr = __root.pthread_attr_setstackaddr;
    pub const getstacksize = __root.pthread_attr_getstacksize;
    pub const setstacksize = __root.pthread_attr_setstacksize;
    pub const getstack = __root.pthread_attr_getstack;
    pub const setstack = __root.pthread_attr_setstack;
    pub const np = __root.pthread_attr_setaffinity_np;
};
pub const pthread_attr_t = union_pthread_attr_t;
pub const pthread_mutex_t = extern union {
    __data: struct___pthread_mutex_s,
    __size: [40]u8,
    __align: c_long,
    pub const pthread_mutex_init = __root.pthread_mutex_init;
    pub const pthread_mutex_destroy = __root.pthread_mutex_destroy;
    pub const pthread_mutex_trylock = __root.pthread_mutex_trylock;
    pub const pthread_mutex_lock = __root.pthread_mutex_lock;
    pub const pthread_mutex_timedlock = __root.pthread_mutex_timedlock;
    pub const pthread_mutex_clocklock = __root.pthread_mutex_clocklock;
    pub const pthread_mutex_unlock = __root.pthread_mutex_unlock;
    pub const pthread_mutex_getprioceiling = __root.pthread_mutex_getprioceiling;
    pub const pthread_mutex_setprioceiling = __root.pthread_mutex_setprioceiling;
    pub const pthread_mutex_consistent = __root.pthread_mutex_consistent;
    pub const pthread_mutex_consistent_np = __root.pthread_mutex_consistent_np;
    pub const init = __root.pthread_mutex_init;
    pub const destroy = __root.pthread_mutex_destroy;
    pub const trylock = __root.pthread_mutex_trylock;
    pub const lock = __root.pthread_mutex_lock;
    pub const timedlock = __root.pthread_mutex_timedlock;
    pub const clocklock = __root.pthread_mutex_clocklock;
    pub const unlock = __root.pthread_mutex_unlock;
    pub const getprioceiling = __root.pthread_mutex_getprioceiling;
    pub const setprioceiling = __root.pthread_mutex_setprioceiling;
    pub const consistent = __root.pthread_mutex_consistent;
    pub const np = __root.pthread_mutex_consistent_np;
};
pub const pthread_cond_t = extern union {
    __data: struct___pthread_cond_s,
    __size: [48]u8,
    __align: c_longlong,
    pub const pthread_cond_init = __root.pthread_cond_init;
    pub const pthread_cond_destroy = __root.pthread_cond_destroy;
    pub const pthread_cond_signal = __root.pthread_cond_signal;
    pub const pthread_cond_broadcast = __root.pthread_cond_broadcast;
    pub const pthread_cond_wait = __root.pthread_cond_wait;
    pub const pthread_cond_timedwait = __root.pthread_cond_timedwait;
    pub const pthread_cond_clockwait = __root.pthread_cond_clockwait;
    pub const init = __root.pthread_cond_init;
    pub const destroy = __root.pthread_cond_destroy;
    pub const signal = __root.pthread_cond_signal;
    pub const broadcast = __root.pthread_cond_broadcast;
    pub const wait = __root.pthread_cond_wait;
    pub const timedwait = __root.pthread_cond_timedwait;
    pub const clockwait = __root.pthread_cond_clockwait;
};
pub const pthread_rwlock_t = extern union {
    __data: struct___pthread_rwlock_arch_t,
    __size: [56]u8,
    __align: c_long,
    pub const pthread_rwlock_init = __root.pthread_rwlock_init;
    pub const pthread_rwlock_destroy = __root.pthread_rwlock_destroy;
    pub const pthread_rwlock_rdlock = __root.pthread_rwlock_rdlock;
    pub const pthread_rwlock_tryrdlock = __root.pthread_rwlock_tryrdlock;
    pub const pthread_rwlock_timedrdlock = __root.pthread_rwlock_timedrdlock;
    pub const pthread_rwlock_clockrdlock = __root.pthread_rwlock_clockrdlock;
    pub const pthread_rwlock_wrlock = __root.pthread_rwlock_wrlock;
    pub const pthread_rwlock_trywrlock = __root.pthread_rwlock_trywrlock;
    pub const pthread_rwlock_timedwrlock = __root.pthread_rwlock_timedwrlock;
    pub const pthread_rwlock_clockwrlock = __root.pthread_rwlock_clockwrlock;
    pub const pthread_rwlock_unlock = __root.pthread_rwlock_unlock;
    pub const init = __root.pthread_rwlock_init;
    pub const destroy = __root.pthread_rwlock_destroy;
    pub const rdlock = __root.pthread_rwlock_rdlock;
    pub const tryrdlock = __root.pthread_rwlock_tryrdlock;
    pub const timedrdlock = __root.pthread_rwlock_timedrdlock;
    pub const clockrdlock = __root.pthread_rwlock_clockrdlock;
    pub const wrlock = __root.pthread_rwlock_wrlock;
    pub const trywrlock = __root.pthread_rwlock_trywrlock;
    pub const timedwrlock = __root.pthread_rwlock_timedwrlock;
    pub const clockwrlock = __root.pthread_rwlock_clockwrlock;
    pub const unlock = __root.pthread_rwlock_unlock;
};
pub const pthread_rwlockattr_t = extern union {
    __size: [8]u8,
    __align: c_long,
    pub const pthread_rwlockattr_init = __root.pthread_rwlockattr_init;
    pub const pthread_rwlockattr_destroy = __root.pthread_rwlockattr_destroy;
    pub const pthread_rwlockattr_getpshared = __root.pthread_rwlockattr_getpshared;
    pub const pthread_rwlockattr_setpshared = __root.pthread_rwlockattr_setpshared;
    pub const pthread_rwlockattr_getkind_np = __root.pthread_rwlockattr_getkind_np;
    pub const pthread_rwlockattr_setkind_np = __root.pthread_rwlockattr_setkind_np;
    pub const init = __root.pthread_rwlockattr_init;
    pub const destroy = __root.pthread_rwlockattr_destroy;
    pub const getpshared = __root.pthread_rwlockattr_getpshared;
    pub const setpshared = __root.pthread_rwlockattr_setpshared;
    pub const np = __root.pthread_rwlockattr_getkind_np;
};
pub const pthread_spinlock_t = c_int;
pub const pthread_barrier_t = extern union {
    __size: [32]u8,
    __align: c_long,
    pub const pthread_barrier_init = __root.pthread_barrier_init;
    pub const pthread_barrier_destroy = __root.pthread_barrier_destroy;
    pub const pthread_barrier_wait = __root.pthread_barrier_wait;
    pub const init = __root.pthread_barrier_init;
    pub const destroy = __root.pthread_barrier_destroy;
    pub const wait = __root.pthread_barrier_wait;
};
pub const pthread_barrierattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
    pub const pthread_barrierattr_init = __root.pthread_barrierattr_init;
    pub const pthread_barrierattr_destroy = __root.pthread_barrierattr_destroy;
    pub const pthread_barrierattr_getpshared = __root.pthread_barrierattr_getpshared;
    pub const pthread_barrierattr_setpshared = __root.pthread_barrierattr_setpshared;
    pub const init = __root.pthread_barrierattr_init;
    pub const destroy = __root.pthread_barrierattr_destroy;
    pub const getpshared = __root.pthread_barrierattr_getpshared;
    pub const setpshared = __root.pthread_barrierattr_setpshared;
};
pub extern fn __errno_location() [*c]c_int;
pub extern var program_invocation_name: [*c]u8;
pub extern var program_invocation_short_name: [*c]u8;
pub const error_t = c_int;
pub const struct__G_fpos_t = extern struct {
    __pos: __off_t = 0,
    __state: __mbstate_t = @import("std").mem.zeroes(__mbstate_t),
};
pub const __fpos_t = struct__G_fpos_t;
pub const struct__G_fpos64_t = extern struct {
    __pos: __off64_t = 0,
    __state: __mbstate_t = @import("std").mem.zeroes(__mbstate_t),
};
pub const __fpos64_t = struct__G_fpos64_t;
pub const cookie_read_function_t = fn (__cookie: ?*anyopaque, __buf: [*c]u8, __nbytes: usize) callconv(.c) __ssize_t;
pub const cookie_write_function_t = fn (__cookie: ?*anyopaque, __buf: [*c]const u8, __nbytes: usize) callconv(.c) __ssize_t;
pub const cookie_seek_function_t = fn (__cookie: ?*anyopaque, __pos: [*c]__off64_t, __w: c_int) callconv(.c) c_int;
pub const cookie_close_function_t = fn (__cookie: ?*anyopaque) callconv(.c) c_int;
pub const struct__IO_cookie_io_functions_t = extern struct {
    read: ?*const cookie_read_function_t = null,
    write: ?*const cookie_write_function_t = null,
    seek: ?*const cookie_seek_function_t = null,
    close: ?*const cookie_close_function_t = null,
};
pub const cookie_io_functions_t = struct__IO_cookie_io_functions_t;
pub const fpos_t = __fpos64_t;
pub const fpos64_t = __fpos64_t;
pub extern var stdin: [*c]FILE;
pub extern var stdout: [*c]FILE;
pub extern var stderr: [*c]FILE;
pub extern fn remove(__filename: [*c]const u8) c_int;
pub extern fn rename(__old: [*c]const u8, __new: [*c]const u8) c_int;
pub extern fn renameat(__oldfd: c_int, __old: [*c]const u8, __newfd: c_int, __new: [*c]const u8) c_int;
pub extern fn renameat2(__oldfd: c_int, __old: [*c]const u8, __newfd: c_int, __new: [*c]const u8, __flags: c_uint) c_int;
pub extern fn fclose(__stream: [*c]FILE) c_int;
pub extern fn tmpfile() [*c]FILE;
pub extern fn tmpfile64() [*c]FILE;
pub extern fn tmpnam([*c]u8) [*c]u8;
pub extern fn tmpnam_r(__s: [*c]u8) [*c]u8;
pub extern fn tempnam(__dir: [*c]const u8, __pfx: [*c]const u8) [*c]u8;
pub extern fn fflush(__stream: [*c]FILE) c_int;
pub extern fn fflush_unlocked(__stream: [*c]FILE) c_int;
pub extern fn fcloseall() c_int;
pub extern fn fopen(noalias __filename: [*c]const u8, noalias __modes: [*c]const u8) [*c]FILE;
pub extern fn freopen(noalias __filename: [*c]const u8, noalias __modes: [*c]const u8, noalias __stream: [*c]FILE) [*c]FILE;
pub extern fn fopen64(noalias __filename: [*c]const u8, noalias __modes: [*c]const u8) [*c]FILE;
pub extern fn freopen64(noalias __filename: [*c]const u8, noalias __modes: [*c]const u8, noalias __stream: [*c]FILE) [*c]FILE;
pub extern fn fdopen(__fd: c_int, __modes: [*c]const u8) [*c]FILE;
pub extern fn fopencookie(noalias __magic_cookie: ?*anyopaque, noalias __modes: [*c]const u8, __io_funcs: cookie_io_functions_t) [*c]FILE;
pub extern fn fmemopen(__s: ?*anyopaque, __len: usize, __modes: [*c]const u8) [*c]FILE;
pub extern fn open_memstream(__bufloc: [*c][*c]u8, __sizeloc: [*c]usize) [*c]FILE;
pub extern fn setbuf(noalias __stream: [*c]FILE, noalias __buf: [*c]u8) void;
pub extern fn setvbuf(noalias __stream: [*c]FILE, noalias __buf: [*c]u8, __modes: c_int, __n: usize) c_int;
pub extern fn setbuffer(noalias __stream: [*c]FILE, noalias __buf: [*c]u8, __size: usize) void;
pub extern fn setlinebuf(__stream: [*c]FILE) void;
pub extern fn fprintf(noalias __stream: [*c]FILE, noalias __format: [*c]const u8, ...) c_int;
pub extern fn printf(noalias __format: [*c]const u8, ...) c_int;
pub extern fn sprintf(noalias __s: [*c]u8, noalias __format: [*c]const u8, ...) c_int;
pub extern fn vfprintf(noalias __s: [*c]FILE, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_3) c_int;
pub fn vprintf(noalias arg___fmt: [*c]const u8, arg___arg: [*c]struct___va_list_tag_3) callconv(.c) c_int {
    var __fmt = arg___fmt;
    _ = &__fmt;
    var __arg = arg___arg;
    _ = &__arg;
    return vfprintf(stdout, __fmt, __arg);
}
pub extern fn vsprintf(noalias __s: [*c]u8, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn snprintf(noalias __s: [*c]u8, __maxlen: usize, noalias __format: [*c]const u8, ...) c_int;
pub extern fn vsnprintf(noalias __s: [*c]u8, __maxlen: usize, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn vasprintf(noalias __ptr: [*c][*c]u8, noalias __f: [*c]const u8, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn __asprintf(noalias __ptr: [*c][*c]u8, noalias __fmt: [*c]const u8, ...) c_int;
pub extern fn asprintf(noalias __ptr: [*c][*c]u8, noalias __fmt: [*c]const u8, ...) c_int;
pub extern fn vdprintf(__fd: c_int, noalias __fmt: [*c]const u8, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn dprintf(__fd: c_int, noalias __fmt: [*c]const u8, ...) c_int;
pub extern fn fscanf(noalias __stream: [*c]FILE, noalias __format: [*c]const u8, ...) c_int;
pub extern fn scanf(noalias __format: [*c]const u8, ...) c_int;
pub extern fn sscanf(noalias __s: [*c]const u8, noalias __format: [*c]const u8, ...) c_int;
pub extern fn vfscanf(noalias __s: [*c]FILE, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn vscanf(noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn vsscanf(noalias __s: [*c]const u8, noalias __format: [*c]const u8, __arg: [*c]struct___va_list_tag_3) c_int;
pub extern fn fgetc(__stream: [*c]FILE) c_int;
pub extern fn getc(__stream: [*c]FILE) c_int;
pub fn getchar() callconv(.c) c_int {
    return getc(stdin);
}
pub fn getc_unlocked(arg___fp: [*c]FILE) callconv(.c) c_int {
    var __fp = arg___fp;
    _ = &__fp;
    const extern_local___uflow = struct {
        extern fn __uflow([*c]FILE) c_int;
    };
    _ = &extern_local___uflow;
    return if (__builtin.expect(@intFromBool(__fp.*._IO_read_ptr >= __fp.*._IO_read_end), 0) != 0) __uflow(__fp) else @as(c_int, @as([*c]u8, @ptrCast(@alignCast(blk: {
        const ref = &__fp.*._IO_read_ptr;
        const tmp = ref.*;
        ref.* += 1;
        break :blk tmp;
    }))).*);
}
pub fn getchar_unlocked() callconv(.c) c_int {
    const extern_local___uflow = struct {
        extern fn __uflow([*c]FILE) c_int;
    };
    _ = &extern_local___uflow;
    return if (__builtin.expect(@intFromBool(stdin.*._IO_read_ptr >= stdin.*._IO_read_end), 0) != 0) __uflow(stdin) else @as(c_int, @as([*c]u8, @ptrCast(@alignCast(blk: {
        const ref = &stdin.*._IO_read_ptr;
        const tmp = ref.*;
        ref.* += 1;
        break :blk tmp;
    }))).*);
}
pub fn fgetc_unlocked(arg___fp: [*c]FILE) callconv(.c) c_int {
    var __fp = arg___fp;
    _ = &__fp;
    const extern_local___uflow = struct {
        extern fn __uflow([*c]FILE) c_int;
    };
    _ = &extern_local___uflow;
    return if (__builtin.expect(@intFromBool(__fp.*._IO_read_ptr >= __fp.*._IO_read_end), 0) != 0) __uflow(__fp) else @as(c_int, @as([*c]u8, @ptrCast(@alignCast(blk: {
        const ref = &__fp.*._IO_read_ptr;
        const tmp = ref.*;
        ref.* += 1;
        break :blk tmp;
    }))).*);
}
pub extern fn fputc(__c: c_int, __stream: [*c]FILE) c_int;
pub extern fn putc(__c: c_int, __stream: [*c]FILE) c_int;
pub fn putchar(arg___c: c_int) callconv(.c) c_int {
    var __c = arg___c;
    _ = &__c;
    return putc(__c, stdout);
}
pub fn fputc_unlocked(arg___c: c_int, arg___stream: [*c]FILE) callconv(.c) c_int {
    var __c = arg___c;
    _ = &__c;
    var __stream = arg___stream;
    _ = &__stream;
    const extern_local___overflow = struct {
        extern fn __overflow([*c]FILE, c_int) c_int;
    };
    _ = &extern_local___overflow;
    return if (__builtin.expect(@intFromBool(__stream.*._IO_write_ptr >= __stream.*._IO_write_end), 0) != 0) __overflow(__stream, @as(u8, @bitCast(@as(i8, @truncate(__c))))) else @as(c_int, @as(u8, blk: {
        const tmp = @as(u8, @bitCast(@as(i8, @truncate(__c))));
        (blk_1: {
            const ref = &__stream.*._IO_write_ptr;
            const tmp_2 = ref.*;
            ref.* += 1;
            break :blk_1 tmp_2;
        }).* = tmp;
        break :blk tmp;
    }));
}
pub fn putc_unlocked(arg___c: c_int, arg___stream: [*c]FILE) callconv(.c) c_int {
    var __c = arg___c;
    _ = &__c;
    var __stream = arg___stream;
    _ = &__stream;
    const extern_local___overflow = struct {
        extern fn __overflow([*c]FILE, c_int) c_int;
    };
    _ = &extern_local___overflow;
    return if (__builtin.expect(@intFromBool(__stream.*._IO_write_ptr >= __stream.*._IO_write_end), 0) != 0) __overflow(__stream, @as(u8, @bitCast(@as(i8, @truncate(__c))))) else @as(c_int, @as(u8, blk: {
        const tmp = @as(u8, @bitCast(@as(i8, @truncate(__c))));
        (blk_1: {
            const ref = &__stream.*._IO_write_ptr;
            const tmp_2 = ref.*;
            ref.* += 1;
            break :blk_1 tmp_2;
        }).* = tmp;
        break :blk tmp;
    }));
}
pub fn putchar_unlocked(arg___c: c_int) callconv(.c) c_int {
    var __c = arg___c;
    _ = &__c;
    const extern_local___overflow = struct {
        extern fn __overflow([*c]FILE, c_int) c_int;
    };
    _ = &extern_local___overflow;
    return if (__builtin.expect(@intFromBool(stdout.*._IO_write_ptr >= stdout.*._IO_write_end), 0) != 0) __overflow(stdout, @as(u8, @bitCast(@as(i8, @truncate(__c))))) else @as(c_int, @as(u8, blk: {
        const tmp = @as(u8, @bitCast(@as(i8, @truncate(__c))));
        (blk_1: {
            const ref = &stdout.*._IO_write_ptr;
            const tmp_2 = ref.*;
            ref.* += 1;
            break :blk_1 tmp_2;
        }).* = tmp;
        break :blk tmp;
    }));
}
pub extern fn getw(__stream: [*c]FILE) c_int;
pub extern fn putw(__w: c_int, __stream: [*c]FILE) c_int;
pub extern fn fgets(noalias __s: [*c]u8, __n: c_int, noalias __stream: [*c]FILE) [*c]u8;
pub extern fn fgets_unlocked(noalias __s: [*c]u8, __n: c_int, noalias __stream: [*c]FILE) [*c]u8;
pub extern fn __getdelim(noalias __lineptr: [*c][*c]u8, noalias __n: [*c]usize, __delimiter: c_int, noalias __stream: [*c]FILE) __ssize_t;
pub extern fn getdelim(noalias __lineptr: [*c][*c]u8, noalias __n: [*c]usize, __delimiter: c_int, noalias __stream: [*c]FILE) __ssize_t;
pub fn getline(arg___lineptr: [*c][*c]u8, arg___n: [*c]usize, arg___stream: [*c]FILE) callconv(.c) __ssize_t {
    var __lineptr = arg___lineptr;
    _ = &__lineptr;
    var __n = arg___n;
    _ = &__n;
    var __stream = arg___stream;
    _ = &__stream;
    return __getdelim(__lineptr, __n, '\n', __stream);
}
pub extern fn fputs(noalias __s: [*c]const u8, noalias __stream: [*c]FILE) c_int;
pub extern fn puts(__s: [*c]const u8) c_int;
pub extern fn ungetc(__c: c_int, __stream: [*c]FILE) c_int;
pub extern fn fread(noalias __ptr: ?*anyopaque, __size: usize, __n: usize, noalias __stream: [*c]FILE) usize;
pub extern fn fwrite(noalias __ptr: ?*const anyopaque, __size: usize, __n: usize, noalias __s: [*c]FILE) usize;
pub extern fn fputs_unlocked(noalias __s: [*c]const u8, noalias __stream: [*c]FILE) c_int;
pub extern fn fread_unlocked(noalias __ptr: ?*anyopaque, __size: usize, __n: usize, noalias __stream: [*c]FILE) usize;
pub extern fn fwrite_unlocked(noalias __ptr: ?*const anyopaque, __size: usize, __n: usize, noalias __stream: [*c]FILE) usize;
pub extern fn fseek(__stream: [*c]FILE, __off: c_long, __whence: c_int) c_int;
pub extern fn ftell(__stream: [*c]FILE) c_long;
pub extern fn rewind(__stream: [*c]FILE) void;
pub extern fn fseeko(__stream: [*c]FILE, __off: __off64_t, __whence: c_int) c_int;
pub extern fn ftello(__stream: [*c]FILE) __off64_t;
pub extern fn fgetpos(noalias __stream: [*c]FILE, noalias __pos: [*c]fpos_t) c_int;
pub extern fn fsetpos(__stream: [*c]FILE, __pos: [*c]const fpos_t) c_int;
pub extern fn fseeko64(__stream: [*c]FILE, __off: __off64_t, __whence: c_int) c_int;
pub extern fn ftello64(__stream: [*c]FILE) __off64_t;
pub extern fn fgetpos64(noalias __stream: [*c]FILE, noalias __pos: [*c]fpos64_t) c_int;
pub extern fn fsetpos64(__stream: [*c]FILE, __pos: [*c]const fpos64_t) c_int;
pub extern fn clearerr(__stream: [*c]FILE) void;
pub extern fn feof(__stream: [*c]FILE) c_int;
pub extern fn ferror(__stream: [*c]FILE) c_int;
pub extern fn clearerr_unlocked(__stream: [*c]FILE) void;
pub fn feof_unlocked(arg___stream: [*c]FILE) callconv(.c) c_int {
    var __stream = arg___stream;
    _ = &__stream;
    return @intFromBool((__stream.*._flags & _IO_EOF_SEEN) != @as(c_int, 0));
}
pub fn ferror_unlocked(arg___stream: [*c]FILE) callconv(.c) c_int {
    var __stream = arg___stream;
    _ = &__stream;
    return @intFromBool((__stream.*._flags & _IO_ERR_SEEN) != @as(c_int, 0));
}
pub extern fn perror(__s: [*c]const u8) void;
pub extern fn fileno(__stream: [*c]FILE) c_int;
pub extern fn fileno_unlocked(__stream: [*c]FILE) c_int;
pub extern fn pclose(__stream: [*c]FILE) c_int;
pub extern fn popen(__command: [*c]const u8, __modes: [*c]const u8) [*c]FILE;
pub extern fn ctermid(__s: [*c]u8) [*c]u8;
pub extern fn cuserid(__s: [*c]u8) [*c]u8;
pub const struct_obstack = opaque {
    pub const obstack_printf = __root.obstack_printf;
    pub const obstack_vprintf = __root.obstack_vprintf;
};
pub extern fn obstack_printf(noalias __obstack: ?*struct_obstack, noalias __format: [*c]const u8, ...) c_int;
pub extern fn obstack_vprintf(noalias __obstack: ?*struct_obstack, noalias __format: [*c]const u8, __args: [*c]struct___va_list_tag_3) c_int;
pub extern fn flockfile(__stream: [*c]FILE) void;
pub extern fn ftrylockfile(__stream: [*c]FILE) c_int;
pub extern fn funlockfile(__stream: [*c]FILE) void;
pub extern fn __uflow([*c]FILE) c_int;
pub extern fn __overflow([*c]FILE, c_int) c_int;
pub const div_t = extern struct {
    quot: c_int = 0,
    rem: c_int = 0,
};
pub const ldiv_t = extern struct {
    quot: c_long = 0,
    rem: c_long = 0,
};
pub const lldiv_t = extern struct {
    quot: c_longlong = 0,
    rem: c_longlong = 0,
};
pub extern fn __ctype_get_mb_cur_max() usize;
pub fn atof(arg___nptr: [*c]const u8) callconv(.c) f64 {
    var __nptr = arg___nptr;
    _ = &__nptr;
    const extern_local_strtod = struct {
        extern fn strtod(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f64;
    };
    _ = &extern_local_strtod;
    return strtod(__nptr, null);
}
pub fn atoi(arg___nptr: [*c]const u8) callconv(.c) c_int {
    var __nptr = arg___nptr;
    _ = &__nptr;
    const extern_local_strtol = struct {
        extern fn strtol(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_long;
    };
    _ = &extern_local_strtol;
    return @truncate(strtol(__nptr, null, 10));
}
pub fn atol(arg___nptr: [*c]const u8) callconv(.c) c_long {
    var __nptr = arg___nptr;
    _ = &__nptr;
    const extern_local_strtol = struct {
        extern fn strtol(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_long;
    };
    _ = &extern_local_strtol;
    return strtol(__nptr, null, 10);
}
pub fn atoll(arg___nptr: [*c]const u8) callconv(.c) c_longlong {
    var __nptr = arg___nptr;
    _ = &__nptr;
    const extern_local_strtoll = struct {
        extern fn strtoll(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_longlong;
    };
    _ = &extern_local_strtoll;
    return strtoll(__nptr, null, 10);
}
pub extern fn strtod(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f64;
pub extern fn strtof(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f32;
pub extern fn strtold(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) c_longdouble;
pub extern fn strtof32(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f32;
pub extern fn strtof64(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f64;
pub extern fn strtof128(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f128;
pub extern fn strtof32x(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) f64;
pub extern fn strtof64x(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8) c_longdouble;
pub extern fn strtol(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_long;
pub extern fn strtoul(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_ulong;
pub extern fn strtoq(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_longlong;
pub extern fn strtouq(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_ulonglong;
pub extern fn strtoll(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_longlong;
pub extern fn strtoull(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int) c_ulonglong;
pub extern fn strfromd(__dest: [*c]u8, __size: usize, __format: [*c]const u8, __f: f64) c_int;
pub extern fn strfromf(__dest: [*c]u8, __size: usize, __format: [*c]const u8, __f: f32) c_int;
pub extern fn strfroml(__dest: [*c]u8, __size: usize, __format: [*c]const u8, __f: c_longdouble) c_int;
pub extern fn strfromf32(__dest: [*c]u8, __size: usize, __format: [*c]const u8, __f: f32) c_int;
pub extern fn strfromf64(__dest: [*c]u8, __size: usize, __format: [*c]const u8, __f: f64) c_int;
pub extern fn strfromf128(__dest: [*c]u8, __size: usize, __format: [*c]const u8, __f: f128) c_int;
pub extern fn strfromf32x(__dest: [*c]u8, __size: usize, __format: [*c]const u8, __f: f64) c_int;
pub extern fn strfromf64x(__dest: [*c]u8, __size: usize, __format: [*c]const u8, __f: c_longdouble) c_int;
pub extern fn strtol_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int, __loc: locale_t) c_long;
pub extern fn strtoul_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int, __loc: locale_t) c_ulong;
pub extern fn strtoll_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int, __loc: locale_t) c_longlong;
pub extern fn strtoull_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __base: c_int, __loc: locale_t) c_ulonglong;
pub extern fn strtod_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __loc: locale_t) f64;
pub extern fn strtof_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __loc: locale_t) f32;
pub extern fn strtold_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __loc: locale_t) c_longdouble;
pub extern fn strtof32_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __loc: locale_t) f32;
pub extern fn strtof64_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __loc: locale_t) f64;
pub extern fn strtof128_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __loc: locale_t) f128;
pub extern fn strtof32x_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __loc: locale_t) f64;
pub extern fn strtof64x_l(noalias __nptr: [*c]const u8, noalias __endptr: [*c][*c]u8, __loc: locale_t) c_longdouble;
pub extern fn l64a(__n: c_long) [*c]u8;
pub extern fn a64l(__s: [*c]const u8) c_long;
pub extern fn random() c_long;
pub extern fn srandom(__seed: c_uint) void;
pub extern fn initstate(__seed: c_uint, __statebuf: [*c]u8, __statelen: usize) [*c]u8;
pub extern fn setstate(__statebuf: [*c]u8) [*c]u8;
pub const struct_random_data = extern struct {
    fptr: [*c]i32 = null,
    rptr: [*c]i32 = null,
    state: [*c]i32 = null,
    rand_type: c_int = 0,
    rand_deg: c_int = 0,
    rand_sep: c_int = 0,
    end_ptr: [*c]i32 = null,
    pub const random_r = __root.random_r;
    pub const r = __root.random_r;
};
pub extern fn random_r(noalias __buf: [*c]struct_random_data, noalias __result: [*c]i32) c_int;
pub extern fn srandom_r(__seed: c_uint, __buf: [*c]struct_random_data) c_int;
pub extern fn initstate_r(__seed: c_uint, noalias __statebuf: [*c]u8, __statelen: usize, noalias __buf: [*c]struct_random_data) c_int;
pub extern fn setstate_r(noalias __statebuf: [*c]u8, noalias __buf: [*c]struct_random_data) c_int;
pub extern fn rand() c_int;
pub extern fn srand(__seed: c_uint) void;
pub extern fn rand_r(__seed: [*c]c_uint) c_int;
pub extern fn drand48() f64;
pub extern fn erand48(__xsubi: [*c]c_ushort) f64;
pub extern fn lrand48() c_long;
pub extern fn nrand48(__xsubi: [*c]c_ushort) c_long;
pub extern fn mrand48() c_long;
pub extern fn jrand48(__xsubi: [*c]c_ushort) c_long;
pub extern fn srand48(__seedval: c_long) void;
pub extern fn seed48(__seed16v: [*c]c_ushort) [*c]c_ushort;
pub extern fn lcong48(__param: [*c]c_ushort) void;
pub const struct_drand48_data = extern struct {
    __x: [3]c_ushort = @import("std").mem.zeroes([3]c_ushort),
    __old_x: [3]c_ushort = @import("std").mem.zeroes([3]c_ushort),
    __c: c_ushort = 0,
    __init: c_ushort = 0,
    __a: c_ulonglong = 0,
    pub const drand48_r = __root.drand48_r;
    pub const lrand48_r = __root.lrand48_r;
    pub const mrand48_r = __root.mrand48_r;
    pub const r = __root.drand48_r;
};
pub extern fn drand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]f64) c_int;
pub extern fn erand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]f64) c_int;
pub extern fn lrand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn nrand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn mrand48_r(noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn jrand48_r(__xsubi: [*c]c_ushort, noalias __buffer: [*c]struct_drand48_data, noalias __result: [*c]c_long) c_int;
pub extern fn srand48_r(__seedval: c_long, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn seed48_r(__seed16v: [*c]c_ushort, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn lcong48_r(__param: [*c]c_ushort, __buffer: [*c]struct_drand48_data) c_int;
pub extern fn arc4random() __uint32_t;
pub extern fn arc4random_buf(__buf: ?*anyopaque, __size: usize) void;
pub extern fn arc4random_uniform(__upper_bound: __uint32_t) __uint32_t;
pub extern fn malloc(__size: usize) ?*anyopaque;
pub extern fn calloc(__nmemb: usize, __size: usize) ?*anyopaque;
pub extern fn realloc(__ptr: ?*anyopaque, __size: usize) ?*anyopaque;
pub extern fn free(__ptr: ?*anyopaque) void;
pub extern fn reallocarray(__ptr: ?*anyopaque, __nmemb: usize, __size: usize) ?*anyopaque;
pub extern fn alloca(__size: usize) ?*anyopaque;
pub extern fn valloc(__size: usize) ?*anyopaque;
pub extern fn posix_memalign(__memptr: [*c]?*anyopaque, __alignment: usize, __size: usize) c_int;
pub extern fn aligned_alloc(__alignment: usize, __size: usize) ?*anyopaque;
pub extern fn abort() noreturn;
pub extern fn atexit(__func: ?*const fn () callconv(.c) void) c_int;
pub extern fn at_quick_exit(__func: ?*const fn () callconv(.c) void) c_int;
pub extern fn on_exit(__func: ?*const fn (__status: c_int, __arg: ?*anyopaque) callconv(.c) void, __arg: ?*anyopaque) c_int;
pub extern fn exit(__status: c_int) noreturn;
pub extern fn quick_exit(__status: c_int) noreturn;
pub extern fn _Exit(__status: c_int) noreturn;
pub extern fn getenv(__name: [*c]const u8) [*c]u8;
pub extern fn secure_getenv(__name: [*c]const u8) [*c]u8;
pub extern fn putenv(__string: [*c]u8) c_int;
pub extern fn setenv(__name: [*c]const u8, __value: [*c]const u8, __replace: c_int) c_int;
pub extern fn unsetenv(__name: [*c]const u8) c_int;
pub extern fn clearenv() c_int;
pub extern fn mktemp(__template: [*c]u8) [*c]u8;
pub extern fn mkstemp(__template: [*c]u8) c_int;
pub extern fn mkstemp64(__template: [*c]u8) c_int;
pub extern fn mkstemps(__template: [*c]u8, __suffixlen: c_int) c_int;
pub extern fn mkstemps64(__template: [*c]u8, __suffixlen: c_int) c_int;
pub extern fn mkdtemp(__template: [*c]u8) [*c]u8;
pub extern fn mkostemp(__template: [*c]u8, __flags: c_int) c_int;
pub extern fn mkostemp64(__template: [*c]u8, __flags: c_int) c_int;
pub extern fn mkostemps(__template: [*c]u8, __suffixlen: c_int, __flags: c_int) c_int;
pub extern fn mkostemps64(__template: [*c]u8, __suffixlen: c_int, __flags: c_int) c_int;
pub extern fn system(__command: [*c]const u8) c_int;
pub extern fn canonicalize_file_name(__name: [*c]const u8) [*c]u8;
pub extern fn realpath(noalias __name: [*c]const u8, noalias __resolved: [*c]u8) [*c]u8;
pub const __compar_fn_t = ?*const fn (?*const anyopaque, ?*const anyopaque) callconv(.c) c_int;
pub const comparison_fn_t = __compar_fn_t;
pub const __compar_d_fn_t = ?*const fn (?*const anyopaque, ?*const anyopaque, ?*anyopaque) callconv(.c) c_int;
pub fn bsearch(arg___key: ?*const anyopaque, arg___base: ?*const anyopaque, arg___nmemb: usize, arg___size: usize, arg___compar: __compar_fn_t) callconv(.c) ?*anyopaque {
    var __key = arg___key;
    _ = &__key;
    var __base = arg___base;
    _ = &__base;
    var __nmemb = arg___nmemb;
    _ = &__nmemb;
    var __size = arg___size;
    _ = &__size;
    var __compar = arg___compar;
    _ = &__compar;
    var __l: usize = undefined;
    _ = &__l;
    var __u: usize = undefined;
    _ = &__u;
    var __idx: usize = undefined;
    _ = &__idx;
    var __p: ?*const anyopaque = undefined;
    _ = &__p;
    var __comparison: c_int = undefined;
    _ = &__comparison;
    __l = 0;
    __u = __nmemb;
    while (__l < __u) {
        __idx = (__l +% __u) / @as(usize, 2);
        __p = @ptrCast(@alignCast(@as([*c]const u8, @ptrCast(@alignCast(__base))) + (__idx *% __size)));
        __comparison = __compar.?(__key, __p);
        if (__comparison < @as(c_int, 0)) {
            __u = __idx;
        } else if (__comparison > @as(c_int, 0)) {
            __l = __idx +% @as(usize, 1);
        } else {
            return @ptrCast(@alignCast(@constCast(__p)));
        }
    }
    return null;
}
pub extern fn qsort(__base: ?*anyopaque, __nmemb: usize, __size: usize, __compar: __compar_fn_t) void;
pub extern fn qsort_r(__base: ?*anyopaque, __nmemb: usize, __size: usize, __compar: __compar_d_fn_t, __arg: ?*anyopaque) void;
pub extern fn abs(__x: c_int) c_int;
pub extern fn labs(__x: c_long) c_long;
pub extern fn llabs(__x: c_longlong) c_longlong;
pub extern fn div(__numer: c_int, __denom: c_int) div_t;
pub extern fn ldiv(__numer: c_long, __denom: c_long) ldiv_t;
pub extern fn lldiv(__numer: c_longlong, __denom: c_longlong) lldiv_t;
pub extern fn ecvt(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn fcvt(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn gcvt(__value: f64, __ndigit: c_int, __buf: [*c]u8) [*c]u8;
pub extern fn qecvt(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn qfcvt(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int) [*c]u8;
pub extern fn qgcvt(__value: c_longdouble, __ndigit: c_int, __buf: [*c]u8) [*c]u8;
pub extern fn ecvt_r(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn fcvt_r(__value: f64, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn qecvt_r(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn qfcvt_r(__value: c_longdouble, __ndigit: c_int, noalias __decpt: [*c]c_int, noalias __sign: [*c]c_int, noalias __buf: [*c]u8, __len: usize) c_int;
pub extern fn mblen(__s: [*c]const u8, __n: usize) c_int;
pub extern fn mbtowc(noalias __pwc: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize) c_int;
pub extern fn wctomb(__s: [*c]u8, __wchar: wchar_t) c_int;
pub extern fn mbstowcs(noalias __pwcs: [*c]wchar_t, noalias __s: [*c]const u8, __n: usize) usize;
pub extern fn wcstombs(noalias __s: [*c]u8, noalias __pwcs: [*c]const wchar_t, __n: usize) usize;
pub extern fn rpmatch(__response: [*c]const u8) c_int;
pub extern fn getsubopt(noalias __optionp: [*c][*c]u8, noalias __tokens: [*c]const [*c]u8, noalias __valuep: [*c][*c]u8) c_int;
pub extern fn posix_openpt(__oflag: c_int) c_int;
pub extern fn grantpt(__fd: c_int) c_int;
pub extern fn unlockpt(__fd: c_int) c_int;
pub extern fn ptsname(__fd: c_int) [*c]u8;
pub extern fn ptsname_r(__fd: c_int, __buf: [*c]u8, __buflen: usize) c_int;
pub extern fn getpt() c_int;
pub extern fn getloadavg(__loadavg: [*c]f64, __nelem: c_int) c_int;
pub extern fn memcpy(noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) ?*anyopaque;
pub extern fn memmove(__dest: ?*anyopaque, __src: ?*const anyopaque, __n: usize) ?*anyopaque;
pub extern fn memccpy(noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __c: c_int, __n: usize) ?*anyopaque;
pub extern fn memset(__s: ?*anyopaque, __c: c_int, __n: usize) ?*anyopaque;
pub extern fn memcmp(__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) c_int;
pub extern fn __memcmpeq(__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) c_int;
pub extern fn memchr(__s: ?*const anyopaque, __c: c_int, __n: usize) ?*anyopaque;
pub extern fn rawmemchr(__s: ?*const anyopaque, __c: c_int) ?*anyopaque;
pub extern fn memrchr(__s: ?*const anyopaque, __c: c_int, __n: usize) ?*anyopaque;
pub extern fn strcpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8) [*c]u8;
pub extern fn strncpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) [*c]u8;
pub extern fn strcat(noalias __dest: [*c]u8, noalias __src: [*c]const u8) [*c]u8;
pub extern fn strncat(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) [*c]u8;
pub extern fn strcmp(__s1: [*c]const u8, __s2: [*c]const u8) c_int;
pub extern fn strncmp(__s1: [*c]const u8, __s2: [*c]const u8, __n: usize) c_int;
pub extern fn strcoll(__s1: [*c]const u8, __s2: [*c]const u8) c_int;
pub extern fn strxfrm(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) usize;
pub extern fn strcoll_l(__s1: [*c]const u8, __s2: [*c]const u8, __l: locale_t) c_int;
pub extern fn strxfrm_l(__dest: [*c]u8, __src: [*c]const u8, __n: usize, __l: locale_t) usize;
pub extern fn strdup(__s: [*c]const u8) [*c]u8;
pub extern fn strndup(__string: [*c]const u8, __n: usize) [*c]u8;
pub extern fn strchr(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn strrchr(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn strchrnul(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn strcspn(__s: [*c]const u8, __reject: [*c]const u8) usize;
pub extern fn strspn(__s: [*c]const u8, __accept: [*c]const u8) usize;
pub extern fn strpbrk(__s: [*c]const u8, __accept: [*c]const u8) [*c]u8;
pub extern fn strstr(__haystack: [*c]const u8, __needle: [*c]const u8) [*c]u8;
pub extern fn strtok(noalias __s: [*c]u8, noalias __delim: [*c]const u8) [*c]u8;
pub extern fn __strtok_r(noalias __s: [*c]u8, noalias __delim: [*c]const u8, noalias __save_ptr: [*c][*c]u8) [*c]u8;
pub extern fn strtok_r(noalias __s: [*c]u8, noalias __delim: [*c]const u8, noalias __save_ptr: [*c][*c]u8) [*c]u8;
pub extern fn strcasestr(__haystack: [*c]const u8, __needle: [*c]const u8) [*c]u8;
pub extern fn memmem(__haystack: ?*const anyopaque, __haystacklen: usize, __needle: ?*const anyopaque, __needlelen: usize) ?*anyopaque;
pub extern fn __mempcpy(noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) ?*anyopaque;
pub extern fn mempcpy(noalias __dest: ?*anyopaque, noalias __src: ?*const anyopaque, __n: usize) ?*anyopaque;
pub extern fn strlen(__s: [*c]const u8) usize;
pub extern fn strnlen(__string: [*c]const u8, __maxlen: usize) usize;
pub extern fn strerror(__errnum: c_int) [*c]u8;
pub extern fn strerror_r(__errnum: c_int, __buf: [*c]u8, __buflen: usize) [*c]u8;
pub extern fn strerrordesc_np(__err: c_int) [*c]const u8;
pub extern fn strerrorname_np(__err: c_int) [*c]const u8;
pub extern fn strerror_l(__errnum: c_int, __l: locale_t) [*c]u8;
pub extern fn bcmp(__s1: ?*const anyopaque, __s2: ?*const anyopaque, __n: usize) c_int;
pub extern fn bcopy(__src: ?*const anyopaque, __dest: ?*anyopaque, __n: usize) void;
pub extern fn bzero(__s: ?*anyopaque, __n: usize) void;
pub extern fn index(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn rindex(__s: [*c]const u8, __c: c_int) [*c]u8;
pub extern fn ffs(__i: c_int) c_int;
pub extern fn ffsl(__l: c_long) c_int;
pub extern fn ffsll(__ll: c_longlong) c_int;
pub extern fn strcasecmp(__s1: [*c]const u8, __s2: [*c]const u8) c_int;
pub extern fn strncasecmp(__s1: [*c]const u8, __s2: [*c]const u8, __n: usize) c_int;
pub extern fn strcasecmp_l(__s1: [*c]const u8, __s2: [*c]const u8, __loc: locale_t) c_int;
pub extern fn strncasecmp_l(__s1: [*c]const u8, __s2: [*c]const u8, __n: usize, __loc: locale_t) c_int;
pub extern fn explicit_bzero(__s: ?*anyopaque, __n: usize) void;
pub extern fn strsep(noalias __stringp: [*c][*c]u8, noalias __delim: [*c]const u8) [*c]u8;
pub extern fn strsignal(__sig: c_int) [*c]u8;
pub extern fn sigabbrev_np(__sig: c_int) [*c]const u8;
pub extern fn sigdescr_np(__sig: c_int) [*c]const u8;
pub extern fn __stpcpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8) [*c]u8;
pub extern fn stpcpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8) [*c]u8;
pub extern fn __stpncpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) [*c]u8;
pub extern fn stpncpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) [*c]u8;
pub extern fn strlcpy(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) usize;
pub extern fn strlcat(noalias __dest: [*c]u8, noalias __src: [*c]const u8, __n: usize) usize;
pub extern fn strverscmp(__s1: [*c]const u8, __s2: [*c]const u8) c_int;
pub extern fn strfry(__string: [*c]u8) [*c]u8;
pub extern fn memfrob(__s: ?*anyopaque, __n: usize) ?*anyopaque;
pub extern fn basename(__filename: [*c]const u8) [*c]u8;
pub const _ISupper: c_int = 256;
pub const _ISlower: c_int = 512;
pub const _ISalpha: c_int = 1024;
pub const _ISdigit: c_int = 2048;
pub const _ISxdigit: c_int = 4096;
pub const _ISspace: c_int = 8192;
pub const _ISprint: c_int = 16384;
pub const _ISgraph: c_int = 32768;
pub const _ISblank: c_int = 1;
pub const _IScntrl: c_int = 2;
pub const _ISpunct: c_int = 4;
pub const _ISalnum: c_int = 8;
const enum_unnamed_7 = c_uint;
pub extern fn __ctype_b_loc() [*c][*c]const c_ushort;
pub extern fn __ctype_tolower_loc() [*c][*c]const __int32_t;
pub extern fn __ctype_toupper_loc() [*c][*c]const __int32_t;
pub extern fn isalnum(c_int) c_int;
pub extern fn isalpha(c_int) c_int;
pub extern fn iscntrl(c_int) c_int;
pub extern fn isdigit(c_int) c_int;
pub extern fn islower(c_int) c_int;
pub extern fn isgraph(c_int) c_int;
pub extern fn isprint(c_int) c_int;
pub extern fn ispunct(c_int) c_int;
pub extern fn isspace(c_int) c_int;
pub extern fn isupper(c_int) c_int;
pub extern fn isxdigit(c_int) c_int;
pub fn tolower(arg___c: c_int) callconv(.c) c_int {
    var __c = arg___c;
    _ = &__c;
    return if ((__c >= -@as(c_int, 128)) and (__c < @as(c_int, 256))) __ctype_tolower_loc().*[@bitCast(@as(isize, @intCast(__c)))] else __c;
}
pub fn toupper(arg___c: c_int) callconv(.c) c_int {
    var __c = arg___c;
    _ = &__c;
    return if ((__c >= -@as(c_int, 128)) and (__c < @as(c_int, 256))) __ctype_toupper_loc().*[@bitCast(@as(isize, @intCast(__c)))] else __c;
}
pub extern fn isblank(c_int) c_int;
pub extern fn isctype(__c: c_int, __mask: c_int) c_int;
pub extern fn isascii(__c: c_int) c_int;
pub extern fn toascii(__c: c_int) c_int;
pub extern fn _toupper(c_int) c_int;
pub extern fn _tolower(c_int) c_int;
pub extern fn isalnum_l(c_int, locale_t) c_int;
pub extern fn isalpha_l(c_int, locale_t) c_int;
pub extern fn iscntrl_l(c_int, locale_t) c_int;
pub extern fn isdigit_l(c_int, locale_t) c_int;
pub extern fn islower_l(c_int, locale_t) c_int;
pub extern fn isgraph_l(c_int, locale_t) c_int;
pub extern fn isprint_l(c_int, locale_t) c_int;
pub extern fn ispunct_l(c_int, locale_t) c_int;
pub extern fn isspace_l(c_int, locale_t) c_int;
pub extern fn isupper_l(c_int, locale_t) c_int;
pub extern fn isxdigit_l(c_int, locale_t) c_int;
pub extern fn isblank_l(c_int, locale_t) c_int;
pub extern fn __tolower_l(__c: c_int, __l: locale_t) c_int;
pub extern fn tolower_l(__c: c_int, __l: locale_t) c_int;
pub extern fn __toupper_l(__c: c_int, __l: locale_t) c_int;
pub extern fn toupper_l(__c: c_int, __l: locale_t) c_int;
pub const socklen_t = __socklen_t;
pub extern fn access(__name: [*c]const u8, __type: c_int) c_int;
pub extern fn euidaccess(__name: [*c]const u8, __type: c_int) c_int;
pub extern fn eaccess(__name: [*c]const u8, __type: c_int) c_int;
pub extern fn execveat(__fd: c_int, __path: [*c]const u8, __argv: [*c]const [*c]u8, __envp: [*c]const [*c]u8, __flags: c_int) c_int;
pub extern fn faccessat(__fd: c_int, __file: [*c]const u8, __type: c_int, __flag: c_int) c_int;
pub extern fn lseek(__fd: c_int, __offset: __off64_t, __whence: c_int) __off64_t;
pub extern fn lseek64(__fd: c_int, __offset: __off64_t, __whence: c_int) __off64_t;
pub extern fn close(__fd: c_int) c_int;
pub extern fn closefrom(__lowfd: c_int) void;
pub extern fn read(__fd: c_int, __buf: ?*anyopaque, __nbytes: usize) isize;
pub extern fn write(__fd: c_int, __buf: ?*const anyopaque, __n: usize) isize;
pub extern fn pread(__fd: c_int, __buf: ?*anyopaque, __nbytes: usize, __offset: __off64_t) isize;
pub extern fn pwrite(__fd: c_int, __buf: ?*const anyopaque, __nbytes: usize, __offset: __off64_t) isize;
pub extern fn pread64(__fd: c_int, __buf: ?*anyopaque, __nbytes: usize, __offset: __off64_t) isize;
pub extern fn pwrite64(__fd: c_int, __buf: ?*const anyopaque, __n: usize, __offset: __off64_t) isize;
pub extern fn pipe(__pipedes: [*c]c_int) c_int;
pub extern fn pipe2(__pipedes: [*c]c_int, __flags: c_int) c_int;
pub extern fn alarm(__seconds: c_uint) c_uint;
pub extern fn sleep(__seconds: c_uint) c_uint;
pub extern fn ualarm(__value: __useconds_t, __interval: __useconds_t) __useconds_t;
pub extern fn usleep(__useconds: __useconds_t) c_int;
pub extern fn pause() c_int;
pub extern fn chown(__file: [*c]const u8, __owner: __uid_t, __group: __gid_t) c_int;
pub extern fn fchown(__fd: c_int, __owner: __uid_t, __group: __gid_t) c_int;
pub extern fn lchown(__file: [*c]const u8, __owner: __uid_t, __group: __gid_t) c_int;
pub extern fn fchownat(__fd: c_int, __file: [*c]const u8, __owner: __uid_t, __group: __gid_t, __flag: c_int) c_int;
pub extern fn chdir(__path: [*c]const u8) c_int;
pub extern fn fchdir(__fd: c_int) c_int;
pub extern fn getcwd(__buf: [*c]u8, __size: usize) [*c]u8;
pub extern fn get_current_dir_name() [*c]u8;
pub extern fn getwd(__buf: [*c]u8) [*c]u8;
pub extern fn dup(__fd: c_int) c_int;
pub extern fn dup2(__fd: c_int, __fd2: c_int) c_int;
pub extern fn dup3(__fd: c_int, __fd2: c_int, __flags: c_int) c_int;
pub extern var __environ: [*c][*c]u8;
pub extern var environ: [*c][*c]u8;
pub extern fn execve(__path: [*c]const u8, __argv: [*c]const [*c]u8, __envp: [*c]const [*c]u8) c_int;
pub extern fn fexecve(__fd: c_int, __argv: [*c]const [*c]u8, __envp: [*c]const [*c]u8) c_int;
pub extern fn execv(__path: [*c]const u8, __argv: [*c]const [*c]u8) c_int;
pub extern fn execle(__path: [*c]const u8, __arg: [*c]const u8, ...) c_int;
pub extern fn execl(__path: [*c]const u8, __arg: [*c]const u8, ...) c_int;
pub extern fn execvp(__file: [*c]const u8, __argv: [*c]const [*c]u8) c_int;
pub extern fn execlp(__file: [*c]const u8, __arg: [*c]const u8, ...) c_int;
pub extern fn execvpe(__file: [*c]const u8, __argv: [*c]const [*c]u8, __envp: [*c]const [*c]u8) c_int;
pub extern fn nice(__inc: c_int) c_int;
pub extern fn _exit(__status: c_int) noreturn;
pub const _PC_LINK_MAX: c_int = 0;
pub const _PC_MAX_CANON: c_int = 1;
pub const _PC_MAX_INPUT: c_int = 2;
pub const _PC_NAME_MAX: c_int = 3;
pub const _PC_PATH_MAX: c_int = 4;
pub const _PC_PIPE_BUF: c_int = 5;
pub const _PC_CHOWN_RESTRICTED: c_int = 6;
pub const _PC_NO_TRUNC: c_int = 7;
pub const _PC_VDISABLE: c_int = 8;
pub const _PC_SYNC_IO: c_int = 9;
pub const _PC_ASYNC_IO: c_int = 10;
pub const _PC_PRIO_IO: c_int = 11;
pub const _PC_SOCK_MAXBUF: c_int = 12;
pub const _PC_FILESIZEBITS: c_int = 13;
pub const _PC_REC_INCR_XFER_SIZE: c_int = 14;
pub const _PC_REC_MAX_XFER_SIZE: c_int = 15;
pub const _PC_REC_MIN_XFER_SIZE: c_int = 16;
pub const _PC_REC_XFER_ALIGN: c_int = 17;
pub const _PC_ALLOC_SIZE_MIN: c_int = 18;
pub const _PC_SYMLINK_MAX: c_int = 19;
pub const _PC_2_SYMLINKS: c_int = 20;
const enum_unnamed_8 = c_uint;
pub const _SC_ARG_MAX: c_int = 0;
pub const _SC_CHILD_MAX: c_int = 1;
pub const _SC_CLK_TCK: c_int = 2;
pub const _SC_NGROUPS_MAX: c_int = 3;
pub const _SC_OPEN_MAX: c_int = 4;
pub const _SC_STREAM_MAX: c_int = 5;
pub const _SC_TZNAME_MAX: c_int = 6;
pub const _SC_JOB_CONTROL: c_int = 7;
pub const _SC_SAVED_IDS: c_int = 8;
pub const _SC_REALTIME_SIGNALS: c_int = 9;
pub const _SC_PRIORITY_SCHEDULING: c_int = 10;
pub const _SC_TIMERS: c_int = 11;
pub const _SC_ASYNCHRONOUS_IO: c_int = 12;
pub const _SC_PRIORITIZED_IO: c_int = 13;
pub const _SC_SYNCHRONIZED_IO: c_int = 14;
pub const _SC_FSYNC: c_int = 15;
pub const _SC_MAPPED_FILES: c_int = 16;
pub const _SC_MEMLOCK: c_int = 17;
pub const _SC_MEMLOCK_RANGE: c_int = 18;
pub const _SC_MEMORY_PROTECTION: c_int = 19;
pub const _SC_MESSAGE_PASSING: c_int = 20;
pub const _SC_SEMAPHORES: c_int = 21;
pub const _SC_SHARED_MEMORY_OBJECTS: c_int = 22;
pub const _SC_AIO_LISTIO_MAX: c_int = 23;
pub const _SC_AIO_MAX: c_int = 24;
pub const _SC_AIO_PRIO_DELTA_MAX: c_int = 25;
pub const _SC_DELAYTIMER_MAX: c_int = 26;
pub const _SC_MQ_OPEN_MAX: c_int = 27;
pub const _SC_MQ_PRIO_MAX: c_int = 28;
pub const _SC_VERSION: c_int = 29;
pub const _SC_PAGESIZE: c_int = 30;
pub const _SC_RTSIG_MAX: c_int = 31;
pub const _SC_SEM_NSEMS_MAX: c_int = 32;
pub const _SC_SEM_VALUE_MAX: c_int = 33;
pub const _SC_SIGQUEUE_MAX: c_int = 34;
pub const _SC_TIMER_MAX: c_int = 35;
pub const _SC_BC_BASE_MAX: c_int = 36;
pub const _SC_BC_DIM_MAX: c_int = 37;
pub const _SC_BC_SCALE_MAX: c_int = 38;
pub const _SC_BC_STRING_MAX: c_int = 39;
pub const _SC_COLL_WEIGHTS_MAX: c_int = 40;
pub const _SC_EQUIV_CLASS_MAX: c_int = 41;
pub const _SC_EXPR_NEST_MAX: c_int = 42;
pub const _SC_LINE_MAX: c_int = 43;
pub const _SC_RE_DUP_MAX: c_int = 44;
pub const _SC_CHARCLASS_NAME_MAX: c_int = 45;
pub const _SC_2_VERSION: c_int = 46;
pub const _SC_2_C_BIND: c_int = 47;
pub const _SC_2_C_DEV: c_int = 48;
pub const _SC_2_FORT_DEV: c_int = 49;
pub const _SC_2_FORT_RUN: c_int = 50;
pub const _SC_2_SW_DEV: c_int = 51;
pub const _SC_2_LOCALEDEF: c_int = 52;
pub const _SC_PII: c_int = 53;
pub const _SC_PII_XTI: c_int = 54;
pub const _SC_PII_SOCKET: c_int = 55;
pub const _SC_PII_INTERNET: c_int = 56;
pub const _SC_PII_OSI: c_int = 57;
pub const _SC_POLL: c_int = 58;
pub const _SC_SELECT: c_int = 59;
pub const _SC_UIO_MAXIOV: c_int = 60;
pub const _SC_IOV_MAX: c_int = 60;
pub const _SC_PII_INTERNET_STREAM: c_int = 61;
pub const _SC_PII_INTERNET_DGRAM: c_int = 62;
pub const _SC_PII_OSI_COTS: c_int = 63;
pub const _SC_PII_OSI_CLTS: c_int = 64;
pub const _SC_PII_OSI_M: c_int = 65;
pub const _SC_T_IOV_MAX: c_int = 66;
pub const _SC_THREADS: c_int = 67;
pub const _SC_THREAD_SAFE_FUNCTIONS: c_int = 68;
pub const _SC_GETGR_R_SIZE_MAX: c_int = 69;
pub const _SC_GETPW_R_SIZE_MAX: c_int = 70;
pub const _SC_LOGIN_NAME_MAX: c_int = 71;
pub const _SC_TTY_NAME_MAX: c_int = 72;
pub const _SC_THREAD_DESTRUCTOR_ITERATIONS: c_int = 73;
pub const _SC_THREAD_KEYS_MAX: c_int = 74;
pub const _SC_THREAD_STACK_MIN: c_int = 75;
pub const _SC_THREAD_THREADS_MAX: c_int = 76;
pub const _SC_THREAD_ATTR_STACKADDR: c_int = 77;
pub const _SC_THREAD_ATTR_STACKSIZE: c_int = 78;
pub const _SC_THREAD_PRIORITY_SCHEDULING: c_int = 79;
pub const _SC_THREAD_PRIO_INHERIT: c_int = 80;
pub const _SC_THREAD_PRIO_PROTECT: c_int = 81;
pub const _SC_THREAD_PROCESS_SHARED: c_int = 82;
pub const _SC_NPROCESSORS_CONF: c_int = 83;
pub const _SC_NPROCESSORS_ONLN: c_int = 84;
pub const _SC_PHYS_PAGES: c_int = 85;
pub const _SC_AVPHYS_PAGES: c_int = 86;
pub const _SC_ATEXIT_MAX: c_int = 87;
pub const _SC_PASS_MAX: c_int = 88;
pub const _SC_XOPEN_VERSION: c_int = 89;
pub const _SC_XOPEN_XCU_VERSION: c_int = 90;
pub const _SC_XOPEN_UNIX: c_int = 91;
pub const _SC_XOPEN_CRYPT: c_int = 92;
pub const _SC_XOPEN_ENH_I18N: c_int = 93;
pub const _SC_XOPEN_SHM: c_int = 94;
pub const _SC_2_CHAR_TERM: c_int = 95;
pub const _SC_2_C_VERSION: c_int = 96;
pub const _SC_2_UPE: c_int = 97;
pub const _SC_XOPEN_XPG2: c_int = 98;
pub const _SC_XOPEN_XPG3: c_int = 99;
pub const _SC_XOPEN_XPG4: c_int = 100;
pub const _SC_CHAR_BIT: c_int = 101;
pub const _SC_CHAR_MAX: c_int = 102;
pub const _SC_CHAR_MIN: c_int = 103;
pub const _SC_INT_MAX: c_int = 104;
pub const _SC_INT_MIN: c_int = 105;
pub const _SC_LONG_BIT: c_int = 106;
pub const _SC_WORD_BIT: c_int = 107;
pub const _SC_MB_LEN_MAX: c_int = 108;
pub const _SC_NZERO: c_int = 109;
pub const _SC_SSIZE_MAX: c_int = 110;
pub const _SC_SCHAR_MAX: c_int = 111;
pub const _SC_SCHAR_MIN: c_int = 112;
pub const _SC_SHRT_MAX: c_int = 113;
pub const _SC_SHRT_MIN: c_int = 114;
pub const _SC_UCHAR_MAX: c_int = 115;
pub const _SC_UINT_MAX: c_int = 116;
pub const _SC_ULONG_MAX: c_int = 117;
pub const _SC_USHRT_MAX: c_int = 118;
pub const _SC_NL_ARGMAX: c_int = 119;
pub const _SC_NL_LANGMAX: c_int = 120;
pub const _SC_NL_MSGMAX: c_int = 121;
pub const _SC_NL_NMAX: c_int = 122;
pub const _SC_NL_SETMAX: c_int = 123;
pub const _SC_NL_TEXTMAX: c_int = 124;
pub const _SC_XBS5_ILP32_OFF32: c_int = 125;
pub const _SC_XBS5_ILP32_OFFBIG: c_int = 126;
pub const _SC_XBS5_LP64_OFF64: c_int = 127;
pub const _SC_XBS5_LPBIG_OFFBIG: c_int = 128;
pub const _SC_XOPEN_LEGACY: c_int = 129;
pub const _SC_XOPEN_REALTIME: c_int = 130;
pub const _SC_XOPEN_REALTIME_THREADS: c_int = 131;
pub const _SC_ADVISORY_INFO: c_int = 132;
pub const _SC_BARRIERS: c_int = 133;
pub const _SC_BASE: c_int = 134;
pub const _SC_C_LANG_SUPPORT: c_int = 135;
pub const _SC_C_LANG_SUPPORT_R: c_int = 136;
pub const _SC_CLOCK_SELECTION: c_int = 137;
pub const _SC_CPUTIME: c_int = 138;
pub const _SC_THREAD_CPUTIME: c_int = 139;
pub const _SC_DEVICE_IO: c_int = 140;
pub const _SC_DEVICE_SPECIFIC: c_int = 141;
pub const _SC_DEVICE_SPECIFIC_R: c_int = 142;
pub const _SC_FD_MGMT: c_int = 143;
pub const _SC_FIFO: c_int = 144;
pub const _SC_PIPE: c_int = 145;
pub const _SC_FILE_ATTRIBUTES: c_int = 146;
pub const _SC_FILE_LOCKING: c_int = 147;
pub const _SC_FILE_SYSTEM: c_int = 148;
pub const _SC_MONOTONIC_CLOCK: c_int = 149;
pub const _SC_MULTI_PROCESS: c_int = 150;
pub const _SC_SINGLE_PROCESS: c_int = 151;
pub const _SC_NETWORKING: c_int = 152;
pub const _SC_READER_WRITER_LOCKS: c_int = 153;
pub const _SC_SPIN_LOCKS: c_int = 154;
pub const _SC_REGEXP: c_int = 155;
pub const _SC_REGEX_VERSION: c_int = 156;
pub const _SC_SHELL: c_int = 157;
pub const _SC_SIGNALS: c_int = 158;
pub const _SC_SPAWN: c_int = 159;
pub const _SC_SPORADIC_SERVER: c_int = 160;
pub const _SC_THREAD_SPORADIC_SERVER: c_int = 161;
pub const _SC_SYSTEM_DATABASE: c_int = 162;
pub const _SC_SYSTEM_DATABASE_R: c_int = 163;
pub const _SC_TIMEOUTS: c_int = 164;
pub const _SC_TYPED_MEMORY_OBJECTS: c_int = 165;
pub const _SC_USER_GROUPS: c_int = 166;
pub const _SC_USER_GROUPS_R: c_int = 167;
pub const _SC_2_PBS: c_int = 168;
pub const _SC_2_PBS_ACCOUNTING: c_int = 169;
pub const _SC_2_PBS_LOCATE: c_int = 170;
pub const _SC_2_PBS_MESSAGE: c_int = 171;
pub const _SC_2_PBS_TRACK: c_int = 172;
pub const _SC_SYMLOOP_MAX: c_int = 173;
pub const _SC_STREAMS: c_int = 174;
pub const _SC_2_PBS_CHECKPOINT: c_int = 175;
pub const _SC_V6_ILP32_OFF32: c_int = 176;
pub const _SC_V6_ILP32_OFFBIG: c_int = 177;
pub const _SC_V6_LP64_OFF64: c_int = 178;
pub const _SC_V6_LPBIG_OFFBIG: c_int = 179;
pub const _SC_HOST_NAME_MAX: c_int = 180;
pub const _SC_TRACE: c_int = 181;
pub const _SC_TRACE_EVENT_FILTER: c_int = 182;
pub const _SC_TRACE_INHERIT: c_int = 183;
pub const _SC_TRACE_LOG: c_int = 184;
pub const _SC_LEVEL1_ICACHE_SIZE: c_int = 185;
pub const _SC_LEVEL1_ICACHE_ASSOC: c_int = 186;
pub const _SC_LEVEL1_ICACHE_LINESIZE: c_int = 187;
pub const _SC_LEVEL1_DCACHE_SIZE: c_int = 188;
pub const _SC_LEVEL1_DCACHE_ASSOC: c_int = 189;
pub const _SC_LEVEL1_DCACHE_LINESIZE: c_int = 190;
pub const _SC_LEVEL2_CACHE_SIZE: c_int = 191;
pub const _SC_LEVEL2_CACHE_ASSOC: c_int = 192;
pub const _SC_LEVEL2_CACHE_LINESIZE: c_int = 193;
pub const _SC_LEVEL3_CACHE_SIZE: c_int = 194;
pub const _SC_LEVEL3_CACHE_ASSOC: c_int = 195;
pub const _SC_LEVEL3_CACHE_LINESIZE: c_int = 196;
pub const _SC_LEVEL4_CACHE_SIZE: c_int = 197;
pub const _SC_LEVEL4_CACHE_ASSOC: c_int = 198;
pub const _SC_LEVEL4_CACHE_LINESIZE: c_int = 199;
pub const _SC_IPV6: c_int = 235;
pub const _SC_RAW_SOCKETS: c_int = 236;
pub const _SC_V7_ILP32_OFF32: c_int = 237;
pub const _SC_V7_ILP32_OFFBIG: c_int = 238;
pub const _SC_V7_LP64_OFF64: c_int = 239;
pub const _SC_V7_LPBIG_OFFBIG: c_int = 240;
pub const _SC_SS_REPL_MAX: c_int = 241;
pub const _SC_TRACE_EVENT_NAME_MAX: c_int = 242;
pub const _SC_TRACE_NAME_MAX: c_int = 243;
pub const _SC_TRACE_SYS_MAX: c_int = 244;
pub const _SC_TRACE_USER_EVENT_MAX: c_int = 245;
pub const _SC_XOPEN_STREAMS: c_int = 246;
pub const _SC_THREAD_ROBUST_PRIO_INHERIT: c_int = 247;
pub const _SC_THREAD_ROBUST_PRIO_PROTECT: c_int = 248;
pub const _SC_MINSIGSTKSZ: c_int = 249;
pub const _SC_SIGSTKSZ: c_int = 250;
const enum_unnamed_9 = c_uint;
pub const _CS_PATH: c_int = 0;
pub const _CS_V6_WIDTH_RESTRICTED_ENVS: c_int = 1;
pub const _CS_GNU_LIBC_VERSION: c_int = 2;
pub const _CS_GNU_LIBPTHREAD_VERSION: c_int = 3;
pub const _CS_V5_WIDTH_RESTRICTED_ENVS: c_int = 4;
pub const _CS_V7_WIDTH_RESTRICTED_ENVS: c_int = 5;
pub const _CS_LFS_CFLAGS: c_int = 1000;
pub const _CS_LFS_LDFLAGS: c_int = 1001;
pub const _CS_LFS_LIBS: c_int = 1002;
pub const _CS_LFS_LINTFLAGS: c_int = 1003;
pub const _CS_LFS64_CFLAGS: c_int = 1004;
pub const _CS_LFS64_LDFLAGS: c_int = 1005;
pub const _CS_LFS64_LIBS: c_int = 1006;
pub const _CS_LFS64_LINTFLAGS: c_int = 1007;
pub const _CS_XBS5_ILP32_OFF32_CFLAGS: c_int = 1100;
pub const _CS_XBS5_ILP32_OFF32_LDFLAGS: c_int = 1101;
pub const _CS_XBS5_ILP32_OFF32_LIBS: c_int = 1102;
pub const _CS_XBS5_ILP32_OFF32_LINTFLAGS: c_int = 1103;
pub const _CS_XBS5_ILP32_OFFBIG_CFLAGS: c_int = 1104;
pub const _CS_XBS5_ILP32_OFFBIG_LDFLAGS: c_int = 1105;
pub const _CS_XBS5_ILP32_OFFBIG_LIBS: c_int = 1106;
pub const _CS_XBS5_ILP32_OFFBIG_LINTFLAGS: c_int = 1107;
pub const _CS_XBS5_LP64_OFF64_CFLAGS: c_int = 1108;
pub const _CS_XBS5_LP64_OFF64_LDFLAGS: c_int = 1109;
pub const _CS_XBS5_LP64_OFF64_LIBS: c_int = 1110;
pub const _CS_XBS5_LP64_OFF64_LINTFLAGS: c_int = 1111;
pub const _CS_XBS5_LPBIG_OFFBIG_CFLAGS: c_int = 1112;
pub const _CS_XBS5_LPBIG_OFFBIG_LDFLAGS: c_int = 1113;
pub const _CS_XBS5_LPBIG_OFFBIG_LIBS: c_int = 1114;
pub const _CS_XBS5_LPBIG_OFFBIG_LINTFLAGS: c_int = 1115;
pub const _CS_POSIX_V6_ILP32_OFF32_CFLAGS: c_int = 1116;
pub const _CS_POSIX_V6_ILP32_OFF32_LDFLAGS: c_int = 1117;
pub const _CS_POSIX_V6_ILP32_OFF32_LIBS: c_int = 1118;
pub const _CS_POSIX_V6_ILP32_OFF32_LINTFLAGS: c_int = 1119;
pub const _CS_POSIX_V6_ILP32_OFFBIG_CFLAGS: c_int = 1120;
pub const _CS_POSIX_V6_ILP32_OFFBIG_LDFLAGS: c_int = 1121;
pub const _CS_POSIX_V6_ILP32_OFFBIG_LIBS: c_int = 1122;
pub const _CS_POSIX_V6_ILP32_OFFBIG_LINTFLAGS: c_int = 1123;
pub const _CS_POSIX_V6_LP64_OFF64_CFLAGS: c_int = 1124;
pub const _CS_POSIX_V6_LP64_OFF64_LDFLAGS: c_int = 1125;
pub const _CS_POSIX_V6_LP64_OFF64_LIBS: c_int = 1126;
pub const _CS_POSIX_V6_LP64_OFF64_LINTFLAGS: c_int = 1127;
pub const _CS_POSIX_V6_LPBIG_OFFBIG_CFLAGS: c_int = 1128;
pub const _CS_POSIX_V6_LPBIG_OFFBIG_LDFLAGS: c_int = 1129;
pub const _CS_POSIX_V6_LPBIG_OFFBIG_LIBS: c_int = 1130;
pub const _CS_POSIX_V6_LPBIG_OFFBIG_LINTFLAGS: c_int = 1131;
pub const _CS_POSIX_V7_ILP32_OFF32_CFLAGS: c_int = 1132;
pub const _CS_POSIX_V7_ILP32_OFF32_LDFLAGS: c_int = 1133;
pub const _CS_POSIX_V7_ILP32_OFF32_LIBS: c_int = 1134;
pub const _CS_POSIX_V7_ILP32_OFF32_LINTFLAGS: c_int = 1135;
pub const _CS_POSIX_V7_ILP32_OFFBIG_CFLAGS: c_int = 1136;
pub const _CS_POSIX_V7_ILP32_OFFBIG_LDFLAGS: c_int = 1137;
pub const _CS_POSIX_V7_ILP32_OFFBIG_LIBS: c_int = 1138;
pub const _CS_POSIX_V7_ILP32_OFFBIG_LINTFLAGS: c_int = 1139;
pub const _CS_POSIX_V7_LP64_OFF64_CFLAGS: c_int = 1140;
pub const _CS_POSIX_V7_LP64_OFF64_LDFLAGS: c_int = 1141;
pub const _CS_POSIX_V7_LP64_OFF64_LIBS: c_int = 1142;
pub const _CS_POSIX_V7_LP64_OFF64_LINTFLAGS: c_int = 1143;
pub const _CS_POSIX_V7_LPBIG_OFFBIG_CFLAGS: c_int = 1144;
pub const _CS_POSIX_V7_LPBIG_OFFBIG_LDFLAGS: c_int = 1145;
pub const _CS_POSIX_V7_LPBIG_OFFBIG_LIBS: c_int = 1146;
pub const _CS_POSIX_V7_LPBIG_OFFBIG_LINTFLAGS: c_int = 1147;
pub const _CS_V6_ENV: c_int = 1148;
pub const _CS_V7_ENV: c_int = 1149;
const enum_unnamed_10 = c_uint;
pub extern fn pathconf(__path: [*c]const u8, __name: c_int) c_long;
pub extern fn fpathconf(__fd: c_int, __name: c_int) c_long;
pub extern fn sysconf(__name: c_int) c_long;
pub extern fn confstr(__name: c_int, __buf: [*c]u8, __len: usize) usize;
pub extern fn getpid() __pid_t;
pub extern fn getppid() __pid_t;
pub extern fn getpgrp() __pid_t;
pub extern fn __getpgid(__pid: __pid_t) __pid_t;
pub extern fn getpgid(__pid: __pid_t) __pid_t;
pub extern fn setpgid(__pid: __pid_t, __pgid: __pid_t) c_int;
pub extern fn setpgrp() c_int;
pub extern fn setsid() __pid_t;
pub extern fn getsid(__pid: __pid_t) __pid_t;
pub extern fn getuid() __uid_t;
pub extern fn geteuid() __uid_t;
pub extern fn getgid() __gid_t;
pub extern fn getegid() __gid_t;
pub extern fn getgroups(__size: c_int, __list: [*c]__gid_t) c_int;
pub extern fn group_member(__gid: __gid_t) c_int;
pub extern fn setuid(__uid: __uid_t) c_int;
pub extern fn setreuid(__ruid: __uid_t, __euid: __uid_t) c_int;
pub extern fn seteuid(__uid: __uid_t) c_int;
pub extern fn setgid(__gid: __gid_t) c_int;
pub extern fn setregid(__rgid: __gid_t, __egid: __gid_t) c_int;
pub extern fn setegid(__gid: __gid_t) c_int;
pub extern fn getresuid(__ruid: [*c]__uid_t, __euid: [*c]__uid_t, __suid: [*c]__uid_t) c_int;
pub extern fn getresgid(__rgid: [*c]__gid_t, __egid: [*c]__gid_t, __sgid: [*c]__gid_t) c_int;
pub extern fn setresuid(__ruid: __uid_t, __euid: __uid_t, __suid: __uid_t) c_int;
pub extern fn setresgid(__rgid: __gid_t, __egid: __gid_t, __sgid: __gid_t) c_int;
pub extern fn fork() __pid_t;
pub extern fn vfork() __pid_t;
pub extern fn _Fork() __pid_t;
pub extern fn ttyname(__fd: c_int) [*c]u8;
pub extern fn ttyname_r(__fd: c_int, __buf: [*c]u8, __buflen: usize) c_int;
pub extern fn isatty(__fd: c_int) c_int;
pub extern fn ttyslot() c_int;
pub extern fn link(__from: [*c]const u8, __to: [*c]const u8) c_int;
pub extern fn linkat(__fromfd: c_int, __from: [*c]const u8, __tofd: c_int, __to: [*c]const u8, __flags: c_int) c_int;
pub extern fn symlink(__from: [*c]const u8, __to: [*c]const u8) c_int;
pub extern fn readlink(noalias __path: [*c]const u8, noalias __buf: [*c]u8, __len: usize) isize;
pub extern fn symlinkat(__from: [*c]const u8, __tofd: c_int, __to: [*c]const u8) c_int;
pub extern fn readlinkat(__fd: c_int, noalias __path: [*c]const u8, noalias __buf: [*c]u8, __len: usize) isize;
pub extern fn unlink(__name: [*c]const u8) c_int;
pub extern fn unlinkat(__fd: c_int, __name: [*c]const u8, __flag: c_int) c_int;
pub extern fn rmdir(__path: [*c]const u8) c_int;
pub extern fn tcgetpgrp(__fd: c_int) __pid_t;
pub extern fn tcsetpgrp(__fd: c_int, __pgrp_id: __pid_t) c_int;
pub extern fn getlogin() [*c]u8;
pub extern fn getlogin_r(__name: [*c]u8, __name_len: usize) c_int;
pub extern fn setlogin(__name: [*c]const u8) c_int;
pub extern var optarg: [*c]u8;
pub extern var optind: c_int;
pub extern var opterr: c_int;
pub extern var optopt: c_int;
pub extern fn getopt(___argc: c_int, ___argv: [*c]const [*c]u8, __shortopts: [*c]const u8) c_int;
pub extern fn gethostname(__name: [*c]u8, __len: usize) c_int;
pub extern fn sethostname(__name: [*c]const u8, __len: usize) c_int;
pub extern fn sethostid(__id: c_long) c_int;
pub extern fn getdomainname(__name: [*c]u8, __len: usize) c_int;
pub extern fn setdomainname(__name: [*c]const u8, __len: usize) c_int;
pub extern fn vhangup() c_int;
pub extern fn revoke(__file: [*c]const u8) c_int;
pub extern fn profil(__sample_buffer: [*c]c_ushort, __size: usize, __offset: usize, __scale: c_uint) c_int;
pub extern fn acct(__name: [*c]const u8) c_int;
pub extern fn getusershell() [*c]u8;
pub extern fn endusershell() void;
pub extern fn setusershell() void;
pub extern fn daemon(__nochdir: c_int, __noclose: c_int) c_int;
pub extern fn chroot(__path: [*c]const u8) c_int;
pub extern fn getpass(__prompt: [*c]const u8) [*c]u8;
pub extern fn fsync(__fd: c_int) c_int;
pub extern fn syncfs(__fd: c_int) c_int;
pub extern fn gethostid() c_long;
pub extern fn sync() void;
pub extern fn getpagesize() c_int;
pub extern fn getdtablesize() c_int;
pub extern fn truncate(__file: [*c]const u8, __length: __off64_t) c_int;
pub extern fn truncate64(__file: [*c]const u8, __length: __off64_t) c_int;
pub extern fn ftruncate(__fd: c_int, __length: __off64_t) c_int;
pub extern fn ftruncate64(__fd: c_int, __length: __off64_t) c_int;
pub extern fn brk(__addr: ?*anyopaque) c_int;
pub extern fn sbrk(__delta: isize) ?*anyopaque;
pub extern fn syscall(__sysno: c_long, ...) c_long;
pub extern fn lockf(__fd: c_int, __cmd: c_int, __len: __off64_t) c_int;
pub extern fn lockf64(__fd: c_int, __cmd: c_int, __len: __off64_t) c_int;
pub extern fn copy_file_range(__infd: c_int, __pinoff: [*c]__off64_t, __outfd: c_int, __poutoff: [*c]__off64_t, __length: usize, __flags: c_uint) isize;
pub extern fn fdatasync(__fildes: c_int) c_int;
pub extern fn crypt(__key: [*c]const u8, __salt: [*c]const u8) [*c]u8;
pub extern fn swab(noalias __from: ?*const anyopaque, noalias __to: ?*anyopaque, __n: isize) void;
pub extern fn getentropy(__buffer: ?*anyopaque, __length: usize) c_int;
pub extern fn close_range(__fd: c_uint, __max_fd: c_uint, __flags: c_int) c_int;
pub extern fn gettid() __pid_t;
pub const Py_uintptr_t = usize;
pub const Py_intptr_t = isize;
pub const Py_ssize_t = isize;
pub const Py_hash_t = Py_ssize_t;
pub const Py_uhash_t = usize;
pub const Py_ssize_clean_t = Py_ssize_t;
pub extern fn Py_PACK_FULL_VERSION(x: c_int, y: c_int, z: c_int, level: c_int, serial: c_int) u32;
pub extern fn Py_PACK_VERSION(x: c_int, y: c_int) u32;
pub extern fn PyMem_Malloc(size: usize) ?*anyopaque;
pub extern fn PyMem_Calloc(nelem: usize, elsize: usize) ?*anyopaque;
pub extern fn PyMem_Realloc(ptr: ?*anyopaque, new_size: usize) ?*anyopaque;
pub extern fn PyMem_Free(ptr: ?*anyopaque) void;
pub extern fn PyMem_RawMalloc(size: usize) ?*anyopaque;
pub extern fn PyMem_RawCalloc(nelem: usize, elsize: usize) ?*anyopaque;
pub extern fn PyMem_RawRealloc(ptr: ?*anyopaque, new_size: usize) ?*anyopaque;
pub extern fn PyMem_RawFree(ptr: ?*anyopaque) void;
pub const PYMEM_DOMAIN_RAW: c_int = 0;
pub const PYMEM_DOMAIN_MEM: c_int = 1;
pub const PYMEM_DOMAIN_OBJ: c_int = 2;
pub const PyMemAllocatorDomain = c_uint;
pub const PYMEM_ALLOCATOR_NOT_SET: c_int = 0;
pub const PYMEM_ALLOCATOR_DEFAULT: c_int = 1;
pub const PYMEM_ALLOCATOR_DEBUG: c_int = 2;
pub const PYMEM_ALLOCATOR_MALLOC: c_int = 3;
pub const PYMEM_ALLOCATOR_MALLOC_DEBUG: c_int = 4;
pub const PYMEM_ALLOCATOR_PYMALLOC: c_int = 5;
pub const PYMEM_ALLOCATOR_PYMALLOC_DEBUG: c_int = 6;
pub const PYMEM_ALLOCATOR_MIMALLOC: c_int = 7;
pub const PYMEM_ALLOCATOR_MIMALLOC_DEBUG: c_int = 8;
pub const PyMemAllocatorName = c_uint;
pub const PyMemAllocatorEx = extern struct {
    ctx: ?*anyopaque = null,
    malloc: ?*const fn (ctx: ?*anyopaque, size: usize) callconv(.c) ?*anyopaque = null,
    calloc: ?*const fn (ctx: ?*anyopaque, nelem: usize, elsize: usize) callconv(.c) ?*anyopaque = null,
    realloc: ?*const fn (ctx: ?*anyopaque, ptr: ?*anyopaque, new_size: usize) callconv(.c) ?*anyopaque = null,
    free: ?*const fn (ctx: ?*anyopaque, ptr: ?*anyopaque) callconv(.c) void = null,
};
pub extern fn PyMem_GetAllocator(domain: PyMemAllocatorDomain, allocator: [*c]PyMemAllocatorEx) void;
pub extern fn PyMem_SetAllocator(domain: PyMemAllocatorDomain, allocator: [*c]PyMemAllocatorEx) void;
pub extern fn PyMem_SetupDebugHooks() void;
const struct_unnamed_12 = extern struct {
    ob_refcnt: u32 = 0,
    ob_overflow: u16 = 0,
    ob_flags: u16 = 0,
};
const union_unnamed_11 = extern union {
    ob_refcnt_full: i64,
    unnamed_0: struct_unnamed_12,
};
pub const destructor = ?*const fn ([*c]PyObject) callconv(.c) void;
pub const getattrfunc = ?*const fn ([*c]PyObject, [*c]u8) callconv(.c) [*c]PyObject;
pub const setattrfunc = ?*const fn ([*c]PyObject, [*c]u8, [*c]PyObject) callconv(.c) c_int;
pub const reprfunc = ?*const fn ([*c]PyObject) callconv(.c) [*c]PyObject;
pub const hashfunc = ?*const fn ([*c]PyObject) callconv(.c) Py_hash_t;
pub const ternaryfunc = ?*const fn ([*c]PyObject, [*c]PyObject, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const getattrofunc = ?*const fn ([*c]PyObject, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const setattrofunc = ?*const fn ([*c]PyObject, [*c]PyObject, [*c]PyObject) callconv(.c) c_int;
pub const visitproc = ?*const fn ([*c]PyObject, ?*anyopaque) callconv(.c) c_int;
pub const traverseproc = ?*const fn ([*c]PyObject, visitproc, ?*anyopaque) callconv(.c) c_int;
pub const inquiry = ?*const fn ([*c]PyObject) callconv(.c) c_int;
pub const richcmpfunc = ?*const fn ([*c]PyObject, [*c]PyObject, c_int) callconv(.c) [*c]PyObject;
pub const getiterfunc = ?*const fn ([*c]PyObject) callconv(.c) [*c]PyObject;
pub const iternextfunc = ?*const fn ([*c]PyObject) callconv(.c) [*c]PyObject;
pub const PyCFunction = ?*const fn ([*c]PyObject, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const struct_PyMethodDef = extern struct {
    ml_name: [*c]const u8 = null,
    ml_meth: PyCFunction = null,
    ml_flags: c_int = 0,
    ml_doc: [*c]const u8 = null,
    pub const PyCFunction_New = __root.PyCFunction_New;
    pub const PyCFunction_NewEx = __root.PyCFunction_NewEx;
    pub const PyCMethod_New = __root.PyCMethod_New;
    pub const New = __root.PyCFunction_New;
    pub const NewEx = __root.PyCFunction_NewEx;
};
pub const PyMethodDef = struct_PyMethodDef;
pub const struct_PyMemberDef = extern struct {
    name: [*c]const u8 = null,
    type: c_int = 0,
    offset: Py_ssize_t = 0,
    flags: c_int = 0,
    doc: [*c]const u8 = null,
};
pub const PyMemberDef = struct_PyMemberDef;
pub const getter = ?*const fn ([*c]PyObject, ?*anyopaque) callconv(.c) [*c]PyObject;
pub const setter = ?*const fn ([*c]PyObject, [*c]PyObject, ?*anyopaque) callconv(.c) c_int;
pub const struct_PyGetSetDef = extern struct {
    name: [*c]const u8 = null,
    get: getter = null,
    set: setter = null,
    doc: [*c]const u8 = null,
    closure: ?*anyopaque = null,
};
pub const PyGetSetDef = struct_PyGetSetDef;
pub const descrgetfunc = ?*const fn ([*c]PyObject, [*c]PyObject, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const descrsetfunc = ?*const fn ([*c]PyObject, [*c]PyObject, [*c]PyObject) callconv(.c) c_int;
pub const initproc = ?*const fn ([*c]PyObject, [*c]PyObject, [*c]PyObject) callconv(.c) c_int;
pub const allocfunc = ?*const fn ([*c]PyTypeObject, Py_ssize_t) callconv(.c) [*c]PyObject;
pub const newfunc = ?*const fn ([*c]PyTypeObject, [*c]PyObject, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const freefunc = ?*const fn (?*anyopaque) callconv(.c) void;
pub const vectorcallfunc = ?*const fn (callable: [*c]PyObject, args: [*c]const [*c]PyObject, nargsf: usize, kwnames: [*c]PyObject) callconv(.c) [*c]PyObject;
pub const struct__typeobject = extern struct {
    ob_base: PyVarObject = @import("std").mem.zeroes(PyVarObject),
    tp_name: [*c]const u8 = null,
    tp_basicsize: Py_ssize_t = 0,
    tp_itemsize: Py_ssize_t = 0,
    tp_dealloc: destructor = null,
    tp_vectorcall_offset: Py_ssize_t = 0,
    tp_getattr: getattrfunc = null,
    tp_setattr: setattrfunc = null,
    tp_as_async: [*c]PyAsyncMethods = null,
    tp_repr: reprfunc = null,
    tp_as_number: [*c]PyNumberMethods = null,
    tp_as_sequence: [*c]PySequenceMethods = null,
    tp_as_mapping: [*c]PyMappingMethods = null,
    tp_hash: hashfunc = null,
    tp_call: ternaryfunc = null,
    tp_str: reprfunc = null,
    tp_getattro: getattrofunc = null,
    tp_setattro: setattrofunc = null,
    tp_as_buffer: [*c]PyBufferProcs = null,
    tp_flags: c_ulong = 0,
    tp_doc: [*c]const u8 = null,
    tp_traverse: traverseproc = null,
    tp_clear: inquiry = null,
    tp_richcompare: richcmpfunc = null,
    tp_weaklistoffset: Py_ssize_t = 0,
    tp_iter: getiterfunc = null,
    tp_iternext: iternextfunc = null,
    tp_methods: [*c]PyMethodDef = null,
    tp_members: [*c]PyMemberDef = null,
    tp_getset: [*c]PyGetSetDef = null,
    tp_base: [*c]PyTypeObject = null,
    tp_dict: [*c]PyObject = null,
    tp_descr_get: descrgetfunc = null,
    tp_descr_set: descrsetfunc = null,
    tp_dictoffset: Py_ssize_t = 0,
    tp_init: initproc = null,
    tp_alloc: allocfunc = null,
    tp_new: newfunc = null,
    tp_free: freefunc = null,
    tp_is_gc: inquiry = null,
    tp_bases: [*c]PyObject = null,
    tp_mro: [*c]PyObject = null,
    tp_cache: [*c]PyObject = null,
    tp_subclasses: ?*anyopaque = null,
    tp_weaklist: [*c]PyObject = null,
    tp_del: destructor = null,
    tp_version_tag: c_uint = 0,
    tp_finalize: destructor = null,
    tp_vectorcall: vectorcallfunc = null,
    tp_watched: u8 = 0,
    tp_versions_used: u16 = 0,
    pub const PyType_GetSlot = __root.PyType_GetSlot;
    pub const PyType_GetModule = __root.PyType_GetModule;
    pub const PyType_GetModuleState = __root.PyType_GetModuleState;
    pub const PyType_GetName = __root.PyType_GetName;
    pub const PyType_GetQualName = __root.PyType_GetQualName;
    pub const PyType_GetFullyQualifiedName = __root.PyType_GetFullyQualifiedName;
    pub const PyType_GetModuleName = __root.PyType_GetModuleName;
    pub const PyType_FromMetaclass = __root.PyType_FromMetaclass;
    pub const PyType_GetTypeDataSize = __root.PyType_GetTypeDataSize;
    pub const PyType_GetBaseByToken = __root.PyType_GetBaseByToken;
    pub const PyType_IsSubtype = __root.PyType_IsSubtype;
    pub const PyType_GetFlags = __root.PyType_GetFlags;
    pub const PyType_Ready = __root.PyType_Ready;
    pub const PyType_GenericAlloc = __root.PyType_GenericAlloc;
    pub const PyType_GenericNew = __root.PyType_GenericNew;
    pub const PyType_Modified = __root.PyType_Modified;
    pub const _PyType_Name = __root._PyType_Name;
    pub const _PyType_Lookup = __root._PyType_Lookup;
    pub const _PyType_LookupRef = __root._PyType_LookupRef;
    pub const PyType_GetDict = __root.PyType_GetDict;
    pub const PyUnstable_Type_AssignVersionTag = __root.PyUnstable_Type_AssignVersionTag;
    pub const PyType_HasFeature = __root.PyType_HasFeature;
    pub const PyType_GetModuleByDef = __root.PyType_GetModuleByDef;
    pub const PyType_Freeze = __root.PyType_Freeze;
    pub const _PyObject_New = __root._PyObject_New;
    pub const _PyObject_NewVar = __root._PyObject_NewVar;
    pub const _PyObject_GC_New = __root._PyObject_GC_New;
    pub const _PyObject_GC_NewVar = __root._PyObject_GC_NewVar;
    pub const _PyObject_SIZE = __root._PyObject_SIZE;
    pub const _PyObject_VAR_SIZE = __root._PyObject_VAR_SIZE;
    pub const PyType_SUPPORTS_WEAKREFS = __root.PyType_SUPPORTS_WEAKREFS;
    pub const PyUnstable_Object_GC_NewWithExtraData = __root.PyUnstable_Object_GC_NewWithExtraData;
    pub const PyDescr_NewMethod = __root.PyDescr_NewMethod;
    pub const PyDescr_NewClassMethod = __root.PyDescr_NewClassMethod;
    pub const PyDescr_NewMember = __root.PyDescr_NewMember;
    pub const PyDescr_NewGetSet = __root.PyDescr_NewGetSet;
    pub const PyDescr_NewWrapper = __root.PyDescr_NewWrapper;
    pub const PyStructSequence_InitType = __root.PyStructSequence_InitType;
    pub const PyStructSequence_InitType2 = __root.PyStructSequence_InitType2;
    pub const PyStructSequence_New = __root.PyStructSequence_New;
    pub const GetSlot = __root.PyType_GetSlot;
    pub const GetModule = __root.PyType_GetModule;
    pub const GetModuleState = __root.PyType_GetModuleState;
    pub const GetName = __root.PyType_GetName;
    pub const GetQualName = __root.PyType_GetQualName;
    pub const GetFullyQualifiedName = __root.PyType_GetFullyQualifiedName;
    pub const GetModuleName = __root.PyType_GetModuleName;
    pub const FromMetaclass = __root.PyType_FromMetaclass;
    pub const GetTypeDataSize = __root.PyType_GetTypeDataSize;
    pub const GetBaseByToken = __root.PyType_GetBaseByToken;
    pub const IsSubtype = __root.PyType_IsSubtype;
    pub const GetFlags = __root.PyType_GetFlags;
    pub const Ready = __root.PyType_Ready;
    pub const GenericAlloc = __root.PyType_GenericAlloc;
    pub const GenericNew = __root.PyType_GenericNew;
    pub const Modified = __root.PyType_Modified;
    pub const Name = __root._PyType_Name;
    pub const Lookup = __root._PyType_Lookup;
    pub const LookupRef = __root._PyType_LookupRef;
    pub const GetDict = __root.PyType_GetDict;
    pub const AssignVersionTag = __root.PyUnstable_Type_AssignVersionTag;
    pub const HasFeature = __root.PyType_HasFeature;
    pub const GetModuleByDef = __root.PyType_GetModuleByDef;
    pub const Freeze = __root.PyType_Freeze;
    pub const New = __root._PyObject_New;
    pub const NewVar = __root._PyObject_NewVar;
    pub const SIZE = __root._PyObject_SIZE;
    pub const WEAKREFS = __root.PyType_SUPPORTS_WEAKREFS;
    pub const NewWithExtraData = __root.PyUnstable_Object_GC_NewWithExtraData;
    pub const NewMethod = __root.PyDescr_NewMethod;
    pub const NewClassMethod = __root.PyDescr_NewClassMethod;
    pub const NewMember = __root.PyDescr_NewMember;
    pub const NewGetSet = __root.PyDescr_NewGetSet;
    pub const NewWrapper = __root.PyDescr_NewWrapper;
    pub const InitType = __root.PyStructSequence_InitType;
    pub const InitType2 = __root.PyStructSequence_InitType2;
};
pub const PyTypeObject = struct__typeobject;
pub const struct__object = extern struct {
    unnamed_0: union_unnamed_11 = @import("std").mem.zeroes(union_unnamed_11),
    ob_type: [*c]PyTypeObject = null,
    pub const PyObject_CheckBuffer = __root.PyObject_CheckBuffer;
    pub const PyObject_GetBuffer = __root.PyObject_GetBuffer;
    pub const PyObject_CopyData = __root.PyObject_CopyData;
    pub const Py_Is = __root.Py_Is;
    pub const Py_TYPE = __root.Py_TYPE;
    pub const _Py_TYPE = __root._Py_TYPE;
    pub const Py_SIZE = __root.Py_SIZE;
    pub const Py_IS_TYPE = __root.Py_IS_TYPE;
    pub const Py_SET_TYPE = __root.Py_SET_TYPE;
    pub const PyType_FromModuleAndSpec = __root.PyType_FromModuleAndSpec;
    pub const PyObject_GetTypeData = __root.PyObject_GetTypeData;
    pub const PyObject_TypeCheck = __root.PyObject_TypeCheck;
    pub const PyObject_Repr = __root.PyObject_Repr;
    pub const PyObject_Str = __root.PyObject_Str;
    pub const PyObject_ASCII = __root.PyObject_ASCII;
    pub const PyObject_Bytes = __root.PyObject_Bytes;
    pub const PyObject_RichCompare = __root.PyObject_RichCompare;
    pub const PyObject_RichCompareBool = __root.PyObject_RichCompareBool;
    pub const PyObject_GetAttrString = __root.PyObject_GetAttrString;
    pub const PyObject_SetAttrString = __root.PyObject_SetAttrString;
    pub const PyObject_DelAttrString = __root.PyObject_DelAttrString;
    pub const PyObject_HasAttrString = __root.PyObject_HasAttrString;
    pub const PyObject_GetAttr = __root.PyObject_GetAttr;
    pub const PyObject_GetOptionalAttr = __root.PyObject_GetOptionalAttr;
    pub const PyObject_GetOptionalAttrString = __root.PyObject_GetOptionalAttrString;
    pub const PyObject_SetAttr = __root.PyObject_SetAttr;
    pub const PyObject_DelAttr = __root.PyObject_DelAttr;
    pub const PyObject_HasAttr = __root.PyObject_HasAttr;
    pub const PyObject_HasAttrWithError = __root.PyObject_HasAttrWithError;
    pub const PyObject_HasAttrStringWithError = __root.PyObject_HasAttrStringWithError;
    pub const PyObject_SelfIter = __root.PyObject_SelfIter;
    pub const PyObject_GenericGetAttr = __root.PyObject_GenericGetAttr;
    pub const PyObject_GenericSetAttr = __root.PyObject_GenericSetAttr;
    pub const PyObject_GenericSetDict = __root.PyObject_GenericSetDict;
    pub const PyObject_Hash = __root.PyObject_Hash;
    pub const PyObject_HashNotImplemented = __root.PyObject_HashNotImplemented;
    pub const PyObject_IsTrue = __root.PyObject_IsTrue;
    pub const PyObject_Not = __root.PyObject_Not;
    pub const PyCallable_Check = __root.PyCallable_Check;
    pub const PyObject_ClearWeakRefs = __root.PyObject_ClearWeakRefs;
    pub const PyObject_Dir = __root.PyObject_Dir;
    pub const Py_ReprEnter = __root.Py_ReprEnter;
    pub const Py_ReprLeave = __root.Py_ReprLeave;
    pub const Py_IsNone = __root.Py_IsNone;
    pub const _Py_NewReference = __root._Py_NewReference;
    pub const _Py_NewReferenceNoTotal = __root._Py_NewReferenceNoTotal;
    pub const _Py_ResurrectReference = __root._Py_ResurrectReference;
    pub const _Py_ForgetReference = __root._Py_ForgetReference;
    pub const PyObject_Print = __root.PyObject_Print;
    pub const _PyObject_Dump = __root._PyObject_Dump;
    pub const _PyObject_GetAttrId = __root._PyObject_GetAttrId;
    pub const _PyObject_GetDictPtr = __root._PyObject_GetDictPtr;
    pub const PyObject_CallFinalizer = __root.PyObject_CallFinalizer;
    pub const PyObject_CallFinalizerFromDealloc = __root.PyObject_CallFinalizerFromDealloc;
    pub const PyUnstable_Object_ClearWeakRefsNoCallbacks = __root.PyUnstable_Object_ClearWeakRefsNoCallbacks;
    pub const _PyObject_GenericGetAttrWithDict = __root._PyObject_GenericGetAttrWithDict;
    pub const _PyObject_GenericSetAttrWithDict = __root._PyObject_GenericSetAttrWithDict;
    pub const _PyObject_FunctionStr = __root._PyObject_FunctionStr;
    pub const _PyObject_AssertFailed = __root._PyObject_AssertFailed;
    pub const PyObject_GetItemData = __root.PyObject_GetItemData;
    pub const PyObject_VisitManagedDict = __root.PyObject_VisitManagedDict;
    pub const _PyObject_SetManagedDict = __root._PyObject_SetManagedDict;
    pub const PyObject_ClearManagedDict = __root.PyObject_ClearManagedDict;
    pub const PyUnstable_Object_EnableDeferredRefcount = __root.PyUnstable_Object_EnableDeferredRefcount;
    pub const PyUnstable_Object_IsUniqueReferencedTemporary = __root.PyUnstable_Object_IsUniqueReferencedTemporary;
    pub const PyUnstable_IsImmortal = __root.PyUnstable_IsImmortal;
    pub const PyUnstable_TryIncRef = __root.PyUnstable_TryIncRef;
    pub const PyUnstable_EnableTryIncRef = __root.PyUnstable_EnableTryIncRef;
    pub const PyUnstable_Object_IsUniquelyReferenced = __root.PyUnstable_Object_IsUniquelyReferenced;
    pub const PyType_Check = __root.PyType_Check;
    pub const PyType_CheckExact = __root.PyType_CheckExact;
    pub const Py_REFCNT = __root.Py_REFCNT;
    pub const _Py_REFCNT = __root._Py_REFCNT;
    pub const _Py_IsImmortal = __root._Py_IsImmortal;
    pub const _Py_IsStaticImmortal = __root._Py_IsStaticImmortal;
    pub const _Py_SetRefcnt = __root._Py_SetRefcnt;
    pub const Py_SET_REFCNT = __root.Py_SET_REFCNT;
    pub const _Py_Dealloc = __root._Py_Dealloc;
    pub const Py_IncRef = __root.Py_IncRef;
    pub const Py_DecRef = __root.Py_DecRef;
    pub const _Py_IncRef = __root._Py_IncRef;
    pub const _Py_DecRef = __root._Py_DecRef;
    pub const Py_INCREF = __root.Py_INCREF;
    pub const Py_DECREF = __root.Py_DECREF;
    pub const Py_XINCREF = __root.Py_XINCREF;
    pub const Py_XDECREF = __root.Py_XDECREF;
    pub const Py_NewRef = __root.Py_NewRef;
    pub const Py_XNewRef = __root.Py_XNewRef;
    pub const _Py_NewRef = __root._Py_NewRef;
    pub const _Py_XNewRef = __root._Py_XNewRef;
    pub const PyObject_Init = __root.PyObject_Init;
    pub const PyObject_GC_IsTracked = __root.PyObject_GC_IsTracked;
    pub const PyObject_GC_IsFinalized = __root.PyObject_GC_IsFinalized;
    pub const PyObject_IS_GC = __root.PyObject_IS_GC;
    pub const PyObject_GET_WEAKREFS_LISTPTR = __root.PyObject_GET_WEAKREFS_LISTPTR;
    pub const _Py_HashDouble = __root._Py_HashDouble;
    pub const PyObject_GenericHash = __root.PyObject_GenericHash;
    pub const PyByteArray_FromObject = __root.PyByteArray_FromObject;
    pub const PyByteArray_Concat = __root.PyByteArray_Concat;
    pub const PyByteArray_Size = __root.PyByteArray_Size;
    pub const PyByteArray_AsString = __root.PyByteArray_AsString;
    pub const PyByteArray_Resize = __root.PyByteArray_Resize;
    pub const PyByteArray_AS_STRING = __root.PyByteArray_AS_STRING;
    pub const PyByteArray_GET_SIZE = __root.PyByteArray_GET_SIZE;
    pub const PyBytes_FromObject = __root.PyBytes_FromObject;
    pub const PyBytes_Size = __root.PyBytes_Size;
    pub const PyBytes_AsString = __root.PyBytes_AsString;
    pub const PyBytes_Repr = __root.PyBytes_Repr;
    pub const PyBytes_AsStringAndSize = __root.PyBytes_AsStringAndSize;
    pub const PyBytes_AS_STRING = __root.PyBytes_AS_STRING;
    pub const PyBytes_GET_SIZE = __root.PyBytes_GET_SIZE;
    pub const PyBytes_Join = __root.PyBytes_Join;
    pub const _PyBytes_Join = __root._PyBytes_Join;
    pub const PyUnicode_Substring = __root.PyUnicode_Substring;
    pub const PyUnicode_AsUCS4 = __root.PyUnicode_AsUCS4;
    pub const PyUnicode_AsUCS4Copy = __root.PyUnicode_AsUCS4Copy;
    pub const PyUnicode_GetLength = __root.PyUnicode_GetLength;
    pub const PyUnicode_ReadChar = __root.PyUnicode_ReadChar;
    pub const PyUnicode_WriteChar = __root.PyUnicode_WriteChar;
    pub const PyUnicode_FromEncodedObject = __root.PyUnicode_FromEncodedObject;
    pub const PyUnicode_FromObject = __root.PyUnicode_FromObject;
    pub const PyUnicode_AsWideChar = __root.PyUnicode_AsWideChar;
    pub const PyUnicode_AsWideCharString = __root.PyUnicode_AsWideCharString;
    pub const PyUnicode_AsDecodedObject = __root.PyUnicode_AsDecodedObject;
    pub const PyUnicode_AsDecodedUnicode = __root.PyUnicode_AsDecodedUnicode;
    pub const PyUnicode_AsEncodedObject = __root.PyUnicode_AsEncodedObject;
    pub const PyUnicode_AsEncodedString = __root.PyUnicode_AsEncodedString;
    pub const PyUnicode_AsEncodedUnicode = __root.PyUnicode_AsEncodedUnicode;
    pub const PyUnicode_BuildEncodingMap = __root.PyUnicode_BuildEncodingMap;
    pub const PyUnicode_AsUTF8String = __root.PyUnicode_AsUTF8String;
    pub const PyUnicode_AsUTF8AndSize = __root.PyUnicode_AsUTF8AndSize;
    pub const PyUnicode_AsUTF32String = __root.PyUnicode_AsUTF32String;
    pub const PyUnicode_AsUTF16String = __root.PyUnicode_AsUTF16String;
    pub const PyUnicode_AsUnicodeEscapeString = __root.PyUnicode_AsUnicodeEscapeString;
    pub const PyUnicode_AsRawUnicodeEscapeString = __root.PyUnicode_AsRawUnicodeEscapeString;
    pub const PyUnicode_AsLatin1String = __root.PyUnicode_AsLatin1String;
    pub const PyUnicode_AsASCIIString = __root.PyUnicode_AsASCIIString;
    pub const PyUnicode_AsCharmapString = __root.PyUnicode_AsCharmapString;
    pub const PyUnicode_EncodeLocale = __root.PyUnicode_EncodeLocale;
    pub const PyUnicode_FSConverter = __root.PyUnicode_FSConverter;
    pub const PyUnicode_FSDecoder = __root.PyUnicode_FSDecoder;
    pub const PyUnicode_EncodeFSDefault = __root.PyUnicode_EncodeFSDefault;
    pub const PyUnicode_Concat = __root.PyUnicode_Concat;
    pub const PyUnicode_Split = __root.PyUnicode_Split;
    pub const PyUnicode_Splitlines = __root.PyUnicode_Splitlines;
    pub const PyUnicode_Partition = __root.PyUnicode_Partition;
    pub const PyUnicode_RPartition = __root.PyUnicode_RPartition;
    pub const PyUnicode_RSplit = __root.PyUnicode_RSplit;
    pub const PyUnicode_Translate = __root.PyUnicode_Translate;
    pub const PyUnicode_Join = __root.PyUnicode_Join;
    pub const PyUnicode_Tailmatch = __root.PyUnicode_Tailmatch;
    pub const PyUnicode_Find = __root.PyUnicode_Find;
    pub const PyUnicode_FindChar = __root.PyUnicode_FindChar;
    pub const PyUnicode_Count = __root.PyUnicode_Count;
    pub const PyUnicode_Replace = __root.PyUnicode_Replace;
    pub const PyUnicode_Compare = __root.PyUnicode_Compare;
    pub const PyUnicode_CompareWithASCIIString = __root.PyUnicode_CompareWithASCIIString;
    pub const PyUnicode_EqualToUTF8 = __root.PyUnicode_EqualToUTF8;
    pub const PyUnicode_EqualToUTF8AndSize = __root.PyUnicode_EqualToUTF8AndSize;
    pub const PyUnicode_Equal = __root.PyUnicode_Equal;
    pub const PyUnicode_RichCompare = __root.PyUnicode_RichCompare;
    pub const PyUnicode_Format = __root.PyUnicode_Format;
    pub const PyUnicode_Contains = __root.PyUnicode_Contains;
    pub const PyUnicode_IsIdentifier = __root.PyUnicode_IsIdentifier;
    pub const PyUnicode_IS_READY = __root.PyUnicode_IS_READY;
    pub const PyUnicode_KIND = __root.PyUnicode_KIND;
    pub const _PyUnicode_COMPACT_DATA = __root._PyUnicode_COMPACT_DATA;
    pub const PyUnicode_DATA = __root.PyUnicode_DATA;
    pub const _PyUnicode_DATA = __root._PyUnicode_DATA;
    pub const PyUnicode_READY = __root.PyUnicode_READY;
    pub const PyUnicode_CopyCharacters = __root.PyUnicode_CopyCharacters;
    pub const PyUnicode_Fill = __root.PyUnicode_Fill;
    pub const PyUnicode_AsUTF8 = __root.PyUnicode_AsUTF8;
    pub const _PyUnicode_AsString = __root._PyUnicode_AsString;
    pub const PyErr_SetNone = __root.PyErr_SetNone;
    pub const PyErr_SetObject = __root.PyErr_SetObject;
    pub const PyErr_SetString = __root.PyErr_SetString;
    pub const PyErr_Restore = __root.PyErr_Restore;
    pub const PyErr_SetRaisedException = __root.PyErr_SetRaisedException;
    pub const PyErr_SetHandledException = __root.PyErr_SetHandledException;
    pub const PyErr_SetExcInfo = __root.PyErr_SetExcInfo;
    pub const PyErr_GivenExceptionMatches = __root.PyErr_GivenExceptionMatches;
    pub const PyErr_ExceptionMatches = __root.PyErr_ExceptionMatches;
    pub const PyException_SetTraceback = __root.PyException_SetTraceback;
    pub const PyException_GetTraceback = __root.PyException_GetTraceback;
    pub const PyException_GetCause = __root.PyException_GetCause;
    pub const PyException_SetCause = __root.PyException_SetCause;
    pub const PyException_GetContext = __root.PyException_GetContext;
    pub const PyException_SetContext = __root.PyException_SetContext;
    pub const PyException_GetArgs = __root.PyException_GetArgs;
    pub const PyException_SetArgs = __root.PyException_SetArgs;
    pub const PyExceptionClass_Name = __root.PyExceptionClass_Name;
    pub const PyErr_SetFromErrno = __root.PyErr_SetFromErrno;
    pub const PyErr_SetFromErrnoWithFilenameObject = __root.PyErr_SetFromErrnoWithFilenameObject;
    pub const PyErr_SetFromErrnoWithFilenameObjects = __root.PyErr_SetFromErrnoWithFilenameObjects;
    pub const PyErr_SetFromErrnoWithFilename = __root.PyErr_SetFromErrnoWithFilename;
    pub const PyErr_Format = __root.PyErr_Format;
    pub const PyErr_FormatV = __root.PyErr_FormatV;
    pub const PyErr_SetImportErrorSubclass = __root.PyErr_SetImportErrorSubclass;
    pub const PyErr_SetImportError = __root.PyErr_SetImportError;
    pub const PyErr_WriteUnraisable = __root.PyErr_WriteUnraisable;
    pub const PyUnicodeEncodeError_GetEncoding = __root.PyUnicodeEncodeError_GetEncoding;
    pub const PyUnicodeDecodeError_GetEncoding = __root.PyUnicodeDecodeError_GetEncoding;
    pub const PyUnicodeEncodeError_GetObject = __root.PyUnicodeEncodeError_GetObject;
    pub const PyUnicodeDecodeError_GetObject = __root.PyUnicodeDecodeError_GetObject;
    pub const PyUnicodeTranslateError_GetObject = __root.PyUnicodeTranslateError_GetObject;
    pub const PyUnicodeEncodeError_GetStart = __root.PyUnicodeEncodeError_GetStart;
    pub const PyUnicodeDecodeError_GetStart = __root.PyUnicodeDecodeError_GetStart;
    pub const PyUnicodeTranslateError_GetStart = __root.PyUnicodeTranslateError_GetStart;
    pub const PyUnicodeEncodeError_SetStart = __root.PyUnicodeEncodeError_SetStart;
    pub const PyUnicodeDecodeError_SetStart = __root.PyUnicodeDecodeError_SetStart;
    pub const PyUnicodeTranslateError_SetStart = __root.PyUnicodeTranslateError_SetStart;
    pub const PyUnicodeEncodeError_GetEnd = __root.PyUnicodeEncodeError_GetEnd;
    pub const PyUnicodeDecodeError_GetEnd = __root.PyUnicodeDecodeError_GetEnd;
    pub const PyUnicodeTranslateError_GetEnd = __root.PyUnicodeTranslateError_GetEnd;
    pub const PyUnicodeEncodeError_SetEnd = __root.PyUnicodeEncodeError_SetEnd;
    pub const PyUnicodeDecodeError_SetEnd = __root.PyUnicodeDecodeError_SetEnd;
    pub const PyUnicodeTranslateError_SetEnd = __root.PyUnicodeTranslateError_SetEnd;
    pub const PyUnicodeEncodeError_GetReason = __root.PyUnicodeEncodeError_GetReason;
    pub const PyUnicodeDecodeError_GetReason = __root.PyUnicodeDecodeError_GetReason;
    pub const PyUnicodeTranslateError_GetReason = __root.PyUnicodeTranslateError_GetReason;
    pub const PyUnicodeEncodeError_SetReason = __root.PyUnicodeEncodeError_SetReason;
    pub const PyUnicodeDecodeError_SetReason = __root.PyUnicodeDecodeError_SetReason;
    pub const PyUnicodeTranslateError_SetReason = __root.PyUnicodeTranslateError_SetReason;
    pub const _PyErr_ChainExceptions1 = __root._PyErr_ChainExceptions1;
    pub const PyUnstable_Exc_PrepReraiseStar = __root.PyUnstable_Exc_PrepReraiseStar;
    pub const PyErr_SyntaxLocationObject = __root.PyErr_SyntaxLocationObject;
    pub const PyErr_RangedSyntaxLocationObject = __root.PyErr_RangedSyntaxLocationObject;
    pub const PyErr_ProgramTextObject = __root.PyErr_ProgramTextObject;
    pub const PyLong_AsLong = __root.PyLong_AsLong;
    pub const PyLong_AsLongAndOverflow = __root.PyLong_AsLongAndOverflow;
    pub const PyLong_AsSsize_t = __root.PyLong_AsSsize_t;
    pub const PyLong_AsSize_t = __root.PyLong_AsSize_t;
    pub const PyLong_AsUnsignedLong = __root.PyLong_AsUnsignedLong;
    pub const PyLong_AsUnsignedLongMask = __root.PyLong_AsUnsignedLongMask;
    pub const PyLong_AsInt = __root.PyLong_AsInt;
    pub const PyLong_AsInt32 = __root.PyLong_AsInt32;
    pub const PyLong_AsUInt32 = __root.PyLong_AsUInt32;
    pub const PyLong_AsInt64 = __root.PyLong_AsInt64;
    pub const PyLong_AsUInt64 = __root.PyLong_AsUInt64;
    pub const PyLong_AsNativeBytes = __root.PyLong_AsNativeBytes;
    pub const PyLong_AsDouble = __root.PyLong_AsDouble;
    pub const PyLong_AsVoidPtr = __root.PyLong_AsVoidPtr;
    pub const PyLong_AsLongLong = __root.PyLong_AsLongLong;
    pub const PyLong_AsUnsignedLongLong = __root.PyLong_AsUnsignedLongLong;
    pub const PyLong_AsUnsignedLongLongMask = __root.PyLong_AsUnsignedLongLongMask;
    pub const PyLong_AsLongLongAndOverflow = __root.PyLong_AsLongLongAndOverflow;
    pub const PyLong_FromUnicodeObject = __root.PyLong_FromUnicodeObject;
    pub const PyLong_IsPositive = __root.PyLong_IsPositive;
    pub const PyLong_IsNegative = __root.PyLong_IsNegative;
    pub const PyLong_IsZero = __root.PyLong_IsZero;
    pub const PyLong_GetSign = __root.PyLong_GetSign;
    pub const _PyLong_Sign = __root._PyLong_Sign;
    pub const _PyLong_NumBits = __root._PyLong_NumBits;
    pub const _PyLong_GCD = __root._PyLong_GCD;
    pub const PyLong_Export = __root.PyLong_Export;
    pub const Py_IsTrue = __root.Py_IsTrue;
    pub const Py_IsFalse = __root.Py_IsFalse;
    pub const PyFloat_FromString = __root.PyFloat_FromString;
    pub const PyFloat_AsDouble = __root.PyFloat_AsDouble;
    pub const PyFloat_AS_DOUBLE = __root.PyFloat_AS_DOUBLE;
    pub const PyComplex_RealAsDouble = __root.PyComplex_RealAsDouble;
    pub const PyComplex_ImagAsDouble = __root.PyComplex_ImagAsDouble;
    pub const PyComplex_AsCComplex = __root.PyComplex_AsCComplex;
    pub const PyMemoryView_FromObject = __root.PyMemoryView_FromObject;
    pub const PyMemoryView_GetContiguous = __root.PyMemoryView_GetContiguous;
    pub const PyMemoryView_GET_BUFFER = __root.PyMemoryView_GET_BUFFER;
    pub const PyMemoryView_GET_BASE = __root.PyMemoryView_GET_BASE;
    pub const PyTuple_Size = __root.PyTuple_Size;
    pub const PyTuple_GetItem = __root.PyTuple_GetItem;
    pub const PyTuple_SetItem = __root.PyTuple_SetItem;
    pub const PyTuple_GetSlice = __root.PyTuple_GetSlice;
    pub const PyTuple_GET_SIZE = __root.PyTuple_GET_SIZE;
    pub const PyTuple_SET_ITEM = __root.PyTuple_SET_ITEM;
    pub const PyList_Size = __root.PyList_Size;
    pub const PyList_GetItem = __root.PyList_GetItem;
    pub const PyList_GetItemRef = __root.PyList_GetItemRef;
    pub const PyList_SetItem = __root.PyList_SetItem;
    pub const PyList_Insert = __root.PyList_Insert;
    pub const PyList_Append = __root.PyList_Append;
    pub const PyList_GetSlice = __root.PyList_GetSlice;
    pub const PyList_SetSlice = __root.PyList_SetSlice;
    pub const PyList_Sort = __root.PyList_Sort;
    pub const PyList_Reverse = __root.PyList_Reverse;
    pub const PyList_AsTuple = __root.PyList_AsTuple;
    pub const PyList_GET_SIZE = __root.PyList_GET_SIZE;
    pub const PyList_SET_ITEM = __root.PyList_SET_ITEM;
    pub const PyList_Extend = __root.PyList_Extend;
    pub const PyList_Clear = __root.PyList_Clear;
    pub const PyDict_GetItem = __root.PyDict_GetItem;
    pub const PyDict_GetItemWithError = __root.PyDict_GetItemWithError;
    pub const PyDict_SetItem = __root.PyDict_SetItem;
    pub const PyDict_DelItem = __root.PyDict_DelItem;
    pub const PyDict_Clear = __root.PyDict_Clear;
    pub const PyDict_Next = __root.PyDict_Next;
    pub const PyDict_Keys = __root.PyDict_Keys;
    pub const PyDict_Values = __root.PyDict_Values;
    pub const PyDict_Items = __root.PyDict_Items;
    pub const PyDict_Size = __root.PyDict_Size;
    pub const PyDict_Copy = __root.PyDict_Copy;
    pub const PyDict_Contains = __root.PyDict_Contains;
    pub const PyDict_Update = __root.PyDict_Update;
    pub const PyDict_Merge = __root.PyDict_Merge;
    pub const PyDict_MergeFromSeq2 = __root.PyDict_MergeFromSeq2;
    pub const PyDict_GetItemString = __root.PyDict_GetItemString;
    pub const PyDict_SetItemString = __root.PyDict_SetItemString;
    pub const PyDict_DelItemString = __root.PyDict_DelItemString;
    pub const PyDict_GetItemRef = __root.PyDict_GetItemRef;
    pub const PyDict_GetItemStringRef = __root.PyDict_GetItemStringRef;
    pub const PyObject_GenericGetDict = __root.PyObject_GenericGetDict;
    pub const _PyDict_GetItem_KnownHash = __root._PyDict_GetItem_KnownHash;
    pub const _PyDict_GetItemStringWithError = __root._PyDict_GetItemStringWithError;
    pub const PyDict_SetDefault = __root.PyDict_SetDefault;
    pub const PyDict_SetDefaultRef = __root.PyDict_SetDefaultRef;
    pub const PyDict_GET_SIZE = __root.PyDict_GET_SIZE;
    pub const PyDict_ContainsString = __root.PyDict_ContainsString;
    pub const PyDict_Pop = __root.PyDict_Pop;
    pub const PyDict_PopString = __root.PyDict_PopString;
    pub const _PyDict_Pop = __root._PyDict_Pop;
    pub const PyODict_SetItem = __root.PyODict_SetItem;
    pub const PyODict_DelItem = __root.PyODict_DelItem;
    pub const PySet_New = __root.PySet_New;
    pub const PyFrozenSet_New = __root.PyFrozenSet_New;
    pub const PySet_Add = __root.PySet_Add;
    pub const PySet_Clear = __root.PySet_Clear;
    pub const PySet_Contains = __root.PySet_Contains;
    pub const PySet_Discard = __root.PySet_Discard;
    pub const PySet_Pop = __root.PySet_Pop;
    pub const PySet_Size = __root.PySet_Size;
    pub const PySet_GET_SIZE = __root.PySet_GET_SIZE;
    pub const PyCFunction_GetFunction = __root.PyCFunction_GetFunction;
    pub const PyCFunction_GetSelf = __root.PyCFunction_GetSelf;
    pub const PyCFunction_GetFlags = __root.PyCFunction_GetFlags;
    pub const PyCFunction_GET_FUNCTION = __root.PyCFunction_GET_FUNCTION;
    pub const PyCFunction_GET_SELF = __root.PyCFunction_GET_SELF;
    pub const PyCFunction_GET_FLAGS = __root.PyCFunction_GET_FLAGS;
    pub const PyCFunction_GET_CLASS = __root.PyCFunction_GET_CLASS;
    pub const PyModule_NewObject = __root.PyModule_NewObject;
    pub const PyModule_GetDict = __root.PyModule_GetDict;
    pub const PyModule_GetNameObject = __root.PyModule_GetNameObject;
    pub const PyModule_GetName = __root.PyModule_GetName;
    pub const PyModule_GetFilename = __root.PyModule_GetFilename;
    pub const PyModule_GetFilenameObject = __root.PyModule_GetFilenameObject;
    pub const PyModule_GetDef = __root.PyModule_GetDef;
    pub const PyModule_GetState = __root.PyModule_GetState;
    pub const PyFunction_New = __root.PyFunction_New;
    pub const PyFunction_NewWithQualName = __root.PyFunction_NewWithQualName;
    pub const PyFunction_GetCode = __root.PyFunction_GetCode;
    pub const PyFunction_GetGlobals = __root.PyFunction_GetGlobals;
    pub const PyFunction_GetModule = __root.PyFunction_GetModule;
    pub const PyFunction_GetDefaults = __root.PyFunction_GetDefaults;
    pub const PyFunction_SetDefaults = __root.PyFunction_SetDefaults;
    pub const PyFunction_GetKwDefaults = __root.PyFunction_GetKwDefaults;
    pub const PyFunction_SetKwDefaults = __root.PyFunction_SetKwDefaults;
    pub const PyFunction_GetClosure = __root.PyFunction_GetClosure;
    pub const PyFunction_SetClosure = __root.PyFunction_SetClosure;
    pub const PyFunction_GetAnnotations = __root.PyFunction_GetAnnotations;
    pub const PyFunction_SetAnnotations = __root.PyFunction_SetAnnotations;
    pub const PyFunction_GET_CODE = __root.PyFunction_GET_CODE;
    pub const PyFunction_GET_GLOBALS = __root.PyFunction_GET_GLOBALS;
    pub const PyFunction_GET_MODULE = __root.PyFunction_GET_MODULE;
    pub const PyFunction_GET_DEFAULTS = __root.PyFunction_GET_DEFAULTS;
    pub const PyFunction_GET_KW_DEFAULTS = __root.PyFunction_GET_KW_DEFAULTS;
    pub const PyFunction_GET_CLOSURE = __root.PyFunction_GET_CLOSURE;
    pub const PyFunction_GET_ANNOTATIONS = __root.PyFunction_GET_ANNOTATIONS;
    pub const PyClassMethod_New = __root.PyClassMethod_New;
    pub const PyStaticMethod_New = __root.PyStaticMethod_New;
    pub const PyMethod_New = __root.PyMethod_New;
    pub const PyMethod_Function = __root.PyMethod_Function;
    pub const PyMethod_Self = __root.PyMethod_Self;
    pub const PyMethod_GET_FUNCTION = __root.PyMethod_GET_FUNCTION;
    pub const PyMethod_GET_SELF = __root.PyMethod_GET_SELF;
    pub const PyInstanceMethod_New = __root.PyInstanceMethod_New;
    pub const PyInstanceMethod_Function = __root.PyInstanceMethod_Function;
    pub const PyInstanceMethod_GET_FUNCTION = __root.PyInstanceMethod_GET_FUNCTION;
    pub const PyFile_GetLine = __root.PyFile_GetLine;
    pub const PyFile_WriteObject = __root.PyFile_WriteObject;
    pub const PyObject_AsFileDescriptor = __root.PyObject_AsFileDescriptor;
    pub const PyFile_OpenCodeObject = __root.PyFile_OpenCodeObject;
    pub const PyCapsule_GetPointer = __root.PyCapsule_GetPointer;
    pub const PyCapsule_GetDestructor = __root.PyCapsule_GetDestructor;
    pub const PyCapsule_GetName = __root.PyCapsule_GetName;
    pub const PyCapsule_GetContext = __root.PyCapsule_GetContext;
    pub const PyCapsule_IsValid = __root.PyCapsule_IsValid;
    pub const PyCapsule_SetPointer = __root.PyCapsule_SetPointer;
    pub const PyCapsule_SetDestructor = __root.PyCapsule_SetDestructor;
    pub const PyCapsule_SetName = __root.PyCapsule_SetName;
    pub const PyCapsule_SetContext = __root.PyCapsule_SetContext;
    pub const _PyCode_ConstantKey = __root._PyCode_ConstantKey;
    pub const PyCode_Optimize = __root.PyCode_Optimize;
    pub const PyUnstable_Code_GetExtra = __root.PyUnstable_Code_GetExtra;
    pub const PyUnstable_Code_SetExtra = __root.PyUnstable_Code_SetExtra;
    pub const _PyCode_GetExtra = __root._PyCode_GetExtra;
    pub const _PyCode_SetExtra = __root._PyCode_SetExtra;
    pub const PyTraceBack_Print = __root.PyTraceBack_Print;
    pub const PySlice_New = __root.PySlice_New;
    pub const PySlice_GetIndices = __root.PySlice_GetIndices;
    pub const PySlice_GetIndicesEx = __root.PySlice_GetIndicesEx;
    pub const PySlice_Unpack = __root.PySlice_Unpack;
    pub const PyCell_New = __root.PyCell_New;
    pub const PyCell_Get = __root.PyCell_Get;
    pub const PyCell_Set = __root.PyCell_Set;
    pub const PyCell_GET = __root.PyCell_GET;
    pub const PyCell_SET = __root.PyCell_SET;
    pub const PySeqIter_New = __root.PySeqIter_New;
    pub const PyCallIter_New = __root.PyCallIter_New;
    pub const PyState_AddModule = __root.PyState_AddModule;
    pub const PyDictProxy_New = __root.PyDictProxy_New;
    pub const PyWrapper_New = __root.PyWrapper_New;
    pub const PyDescr_IsData = __root.PyDescr_IsData;
    pub const Py_GenericAlias = __root.Py_GenericAlias;
    pub const PyErr_WarnEx = __root.PyErr_WarnEx;
    pub const PyErr_WarnFormat = __root.PyErr_WarnFormat;
    pub const PyErr_ResourceWarning = __root.PyErr_ResourceWarning;
    pub const PyErr_WarnExplicit = __root.PyErr_WarnExplicit;
    pub const PyErr_WarnExplicitObject = __root.PyErr_WarnExplicitObject;
    pub const PyErr_WarnExplicitFormat = __root.PyErr_WarnExplicitFormat;
    pub const PyWeakref_NewRef = __root.PyWeakref_NewRef;
    pub const PyWeakref_NewProxy = __root.PyWeakref_NewProxy;
    pub const PyWeakref_GetObject = __root.PyWeakref_GetObject;
    pub const PyWeakref_GetRef = __root.PyWeakref_GetRef;
    pub const PyWeakref_IsDead = __root.PyWeakref_IsDead;
    pub const PyWeakref_GET_OBJECT = __root.PyWeakref_GET_OBJECT;
    pub const PyStructSequence_SetItem = __root.PyStructSequence_SetItem;
    pub const PyStructSequence_GetItem = __root.PyStructSequence_GetItem;
    pub const PyPickleBuffer_FromObject = __root.PyPickleBuffer_FromObject;
    pub const PyPickleBuffer_GetBuffer = __root.PyPickleBuffer_GetBuffer;
    pub const PyPickleBuffer_Release = __root.PyPickleBuffer_Release;
    pub const PyCodec_Register = __root.PyCodec_Register;
    pub const PyCodec_Unregister = __root.PyCodec_Unregister;
    pub const PyCodec_Encode = __root.PyCodec_Encode;
    pub const PyCodec_Decode = __root.PyCodec_Decode;
    pub const PyCodec_StrictErrors = __root.PyCodec_StrictErrors;
    pub const PyCodec_IgnoreErrors = __root.PyCodec_IgnoreErrors;
    pub const PyCodec_ReplaceErrors = __root.PyCodec_ReplaceErrors;
    pub const PyCodec_XMLCharRefReplaceErrors = __root.PyCodec_XMLCharRefReplaceErrors;
    pub const PyCodec_BackslashReplaceErrors = __root.PyCodec_BackslashReplaceErrors;
    pub const PyCodec_NameReplaceErrors = __root.PyCodec_NameReplaceErrors;
    pub const PyContext_Copy = __root.PyContext_Copy;
    pub const PyContext_Enter = __root.PyContext_Enter;
    pub const PyContext_Exit = __root.PyContext_Exit;
    pub const PyContextVar_Get = __root.PyContextVar_Get;
    pub const PyContextVar_Set = __root.PyContextVar_Set;
    pub const PyContextVar_Reset = __root.PyContextVar_Reset;
    pub const PyArg_Parse = __root.PyArg_Parse;
    pub const PyArg_ParseTuple = __root.PyArg_ParseTuple;
    pub const PyArg_ParseTupleAndKeywords = __root.PyArg_ParseTupleAndKeywords;
    pub const PyArg_VaParse = __root.PyArg_VaParse;
    pub const PyArg_VaParseTupleAndKeywords = __root.PyArg_VaParseTupleAndKeywords;
    pub const PyArg_ValidateKeywordArguments = __root.PyArg_ValidateKeywordArguments;
    pub const PyArg_UnpackTuple = __root.PyArg_UnpackTuple;
    pub const PyModule_AddObjectRef = __root.PyModule_AddObjectRef;
    pub const PyModule_Add = __root.PyModule_Add;
    pub const PyModule_AddObject = __root.PyModule_AddObject;
    pub const PyModule_AddIntConstant = __root.PyModule_AddIntConstant;
    pub const PyModule_AddStringConstant = __root.PyModule_AddStringConstant;
    pub const PyModule_AddType = __root.PyModule_AddType;
    pub const PyModule_SetDocString = __root.PyModule_SetDocString;
    pub const PyModule_AddFunctions = __root.PyModule_AddFunctions;
    pub const PyModule_ExecDef = __root.PyModule_ExecDef;
    pub const _PyArg_ParseTupleAndKeywordsFast = __root._PyArg_ParseTupleAndKeywordsFast;
    pub const PyErr_Display = __root.PyErr_Display;
    pub const PyErr_DisplayException = __root.PyErr_DisplayException;
    pub const PyEval_EvalCode = __root.PyEval_EvalCode;
    pub const PyEval_EvalCodeEx = __root.PyEval_EvalCodeEx;
    pub const PyEval_GetFuncName = __root.PyEval_GetFuncName;
    pub const PyEval_GetFuncDesc = __root.PyEval_GetFuncDesc;
    pub const _PyEval_SliceIndex = __root._PyEval_SliceIndex;
    pub const _PyEval_SliceIndexNotNone = __root._PyEval_SliceIndexNotNone;
    pub const PyOS_FSPath = __root.PyOS_FSPath;
    pub const PyImport_ExecCodeModuleObject = __root.PyImport_ExecCodeModuleObject;
    pub const PyImport_GetModule = __root.PyImport_GetModule;
    pub const PyImport_AddModuleObject = __root.PyImport_AddModuleObject;
    pub const PyImport_ImportModuleLevelObject = __root.PyImport_ImportModuleLevelObject;
    pub const PyImport_GetImporter = __root.PyImport_GetImporter;
    pub const PyImport_Import = __root.PyImport_Import;
    pub const PyImport_ReloadModule = __root.PyImport_ReloadModule;
    pub const PyImport_ImportFrozenModuleObject = __root.PyImport_ImportFrozenModuleObject;
    pub const PyImport_ImportModuleAttr = __root.PyImport_ImportModuleAttr;
    pub const PyObject_CallNoArgs = __root.PyObject_CallNoArgs;
    pub const PyObject_Call = __root.PyObject_Call;
    pub const PyObject_CallObject = __root.PyObject_CallObject;
    pub const PyObject_CallFunction = __root.PyObject_CallFunction;
    pub const PyObject_CallMethod = __root.PyObject_CallMethod;
    pub const PyObject_CallFunctionObjArgs = __root.PyObject_CallFunctionObjArgs;
    pub const PyObject_CallMethodObjArgs = __root.PyObject_CallMethodObjArgs;
    pub const PyVectorcall_Call = __root.PyVectorcall_Call;
    pub const PyObject_Vectorcall = __root.PyObject_Vectorcall;
    pub const PyObject_VectorcallMethod = __root.PyObject_VectorcallMethod;
    pub const PyObject_Type = __root.PyObject_Type;
    pub const PyObject_Size = __root.PyObject_Size;
    pub const PyObject_Length = __root.PyObject_Length;
    pub const PyObject_GetItem = __root.PyObject_GetItem;
    pub const PyObject_SetItem = __root.PyObject_SetItem;
    pub const PyObject_DelItemString = __root.PyObject_DelItemString;
    pub const PyObject_DelItem = __root.PyObject_DelItem;
    pub const PyObject_Format = __root.PyObject_Format;
    pub const PyObject_GetIter = __root.PyObject_GetIter;
    pub const PyObject_GetAIter = __root.PyObject_GetAIter;
    pub const PyIter_Check = __root.PyIter_Check;
    pub const PyAIter_Check = __root.PyAIter_Check;
    pub const PyIter_NextItem = __root.PyIter_NextItem;
    pub const PyIter_Next = __root.PyIter_Next;
    pub const PyIter_Send = __root.PyIter_Send;
    pub const PyNumber_Check = __root.PyNumber_Check;
    pub const PyNumber_Add = __root.PyNumber_Add;
    pub const PyNumber_Subtract = __root.PyNumber_Subtract;
    pub const PyNumber_Multiply = __root.PyNumber_Multiply;
    pub const PyNumber_MatrixMultiply = __root.PyNumber_MatrixMultiply;
    pub const PyNumber_FloorDivide = __root.PyNumber_FloorDivide;
    pub const PyNumber_TrueDivide = __root.PyNumber_TrueDivide;
    pub const PyNumber_Remainder = __root.PyNumber_Remainder;
    pub const PyNumber_Divmod = __root.PyNumber_Divmod;
    pub const PyNumber_Power = __root.PyNumber_Power;
    pub const PyNumber_Negative = __root.PyNumber_Negative;
    pub const PyNumber_Positive = __root.PyNumber_Positive;
    pub const PyNumber_Absolute = __root.PyNumber_Absolute;
    pub const PyNumber_Invert = __root.PyNumber_Invert;
    pub const PyNumber_Lshift = __root.PyNumber_Lshift;
    pub const PyNumber_Rshift = __root.PyNumber_Rshift;
    pub const PyNumber_And = __root.PyNumber_And;
    pub const PyNumber_Xor = __root.PyNumber_Xor;
    pub const PyNumber_Or = __root.PyNumber_Or;
    pub const PyIndex_Check = __root.PyIndex_Check;
    pub const PyNumber_Index = __root.PyNumber_Index;
    pub const PyNumber_AsSsize_t = __root.PyNumber_AsSsize_t;
    pub const PyNumber_Long = __root.PyNumber_Long;
    pub const PyNumber_Float = __root.PyNumber_Float;
    pub const PyNumber_InPlaceAdd = __root.PyNumber_InPlaceAdd;
    pub const PyNumber_InPlaceSubtract = __root.PyNumber_InPlaceSubtract;
    pub const PyNumber_InPlaceMultiply = __root.PyNumber_InPlaceMultiply;
    pub const PyNumber_InPlaceMatrixMultiply = __root.PyNumber_InPlaceMatrixMultiply;
    pub const PyNumber_InPlaceFloorDivide = __root.PyNumber_InPlaceFloorDivide;
    pub const PyNumber_InPlaceTrueDivide = __root.PyNumber_InPlaceTrueDivide;
    pub const PyNumber_InPlaceRemainder = __root.PyNumber_InPlaceRemainder;
    pub const PyNumber_InPlacePower = __root.PyNumber_InPlacePower;
    pub const PyNumber_InPlaceLshift = __root.PyNumber_InPlaceLshift;
    pub const PyNumber_InPlaceRshift = __root.PyNumber_InPlaceRshift;
    pub const PyNumber_InPlaceAnd = __root.PyNumber_InPlaceAnd;
    pub const PyNumber_InPlaceXor = __root.PyNumber_InPlaceXor;
    pub const PyNumber_InPlaceOr = __root.PyNumber_InPlaceOr;
    pub const PyNumber_ToBase = __root.PyNumber_ToBase;
    pub const PySequence_Check = __root.PySequence_Check;
    pub const PySequence_Size = __root.PySequence_Size;
    pub const PySequence_Length = __root.PySequence_Length;
    pub const PySequence_Concat = __root.PySequence_Concat;
    pub const PySequence_Repeat = __root.PySequence_Repeat;
    pub const PySequence_GetItem = __root.PySequence_GetItem;
    pub const PySequence_GetSlice = __root.PySequence_GetSlice;
    pub const PySequence_SetItem = __root.PySequence_SetItem;
    pub const PySequence_DelItem = __root.PySequence_DelItem;
    pub const PySequence_SetSlice = __root.PySequence_SetSlice;
    pub const PySequence_DelSlice = __root.PySequence_DelSlice;
    pub const PySequence_Tuple = __root.PySequence_Tuple;
    pub const PySequence_List = __root.PySequence_List;
    pub const PySequence_Fast = __root.PySequence_Fast;
    pub const PySequence_Count = __root.PySequence_Count;
    pub const PySequence_Contains = __root.PySequence_Contains;
    pub const PySequence_In = __root.PySequence_In;
    pub const PySequence_Index = __root.PySequence_Index;
    pub const PySequence_InPlaceConcat = __root.PySequence_InPlaceConcat;
    pub const PySequence_InPlaceRepeat = __root.PySequence_InPlaceRepeat;
    pub const PyMapping_Check = __root.PyMapping_Check;
    pub const PyMapping_Size = __root.PyMapping_Size;
    pub const PyMapping_Length = __root.PyMapping_Length;
    pub const PyMapping_HasKeyString = __root.PyMapping_HasKeyString;
    pub const PyMapping_HasKey = __root.PyMapping_HasKey;
    pub const PyMapping_HasKeyWithError = __root.PyMapping_HasKeyWithError;
    pub const PyMapping_HasKeyStringWithError = __root.PyMapping_HasKeyStringWithError;
    pub const PyMapping_Keys = __root.PyMapping_Keys;
    pub const PyMapping_Values = __root.PyMapping_Values;
    pub const PyMapping_Items = __root.PyMapping_Items;
    pub const PyMapping_GetItemString = __root.PyMapping_GetItemString;
    pub const PyMapping_GetOptionalItem = __root.PyMapping_GetOptionalItem;
    pub const PyMapping_GetOptionalItemString = __root.PyMapping_GetOptionalItemString;
    pub const PyMapping_SetItemString = __root.PyMapping_SetItemString;
    pub const PyObject_IsInstance = __root.PyObject_IsInstance;
    pub const PyObject_IsSubclass = __root.PyObject_IsSubclass;
    pub const _PyObject_CallMethodId = __root._PyObject_CallMethodId;
    pub const PyVectorcall_Function = __root.PyVectorcall_Function;
    pub const PyObject_VectorcallDict = __root.PyObject_VectorcallDict;
    pub const PyObject_CallOneArg = __root.PyObject_CallOneArg;
    pub const PyObject_CallMethodNoArgs = __root.PyObject_CallMethodNoArgs;
    pub const PyObject_CallMethodOneArg = __root.PyObject_CallMethodOneArg;
    pub const PyObject_LengthHint = __root.PyObject_LengthHint;
    pub const Py_fopen = __root.Py_fopen;
    pub const _Py_fopen_obj = __root._Py_fopen_obj;
    pub const CheckBuffer = __root.PyObject_CheckBuffer;
    pub const GetBuffer = __root.PyObject_GetBuffer;
    pub const CopyData = __root.PyObject_CopyData;
    pub const Is = __root.Py_Is;
    pub const TYPE = __root.Py_TYPE;
    pub const SIZE = __root.Py_SIZE;
    pub const FromModuleAndSpec = __root.PyType_FromModuleAndSpec;
    pub const GetTypeData = __root.PyObject_GetTypeData;
    pub const TypeCheck = __root.PyObject_TypeCheck;
    pub const Repr = __root.PyObject_Repr;
    pub const Str = __root.PyObject_Str;
    pub const ASCII = __root.PyObject_ASCII;
    pub const Bytes = __root.PyObject_Bytes;
    pub const RichCompare = __root.PyObject_RichCompare;
    pub const RichCompareBool = __root.PyObject_RichCompareBool;
    pub const GetAttrString = __root.PyObject_GetAttrString;
    pub const SetAttrString = __root.PyObject_SetAttrString;
    pub const DelAttrString = __root.PyObject_DelAttrString;
    pub const HasAttrString = __root.PyObject_HasAttrString;
    pub const GetAttr = __root.PyObject_GetAttr;
    pub const GetOptionalAttr = __root.PyObject_GetOptionalAttr;
    pub const GetOptionalAttrString = __root.PyObject_GetOptionalAttrString;
    pub const SetAttr = __root.PyObject_SetAttr;
    pub const DelAttr = __root.PyObject_DelAttr;
    pub const HasAttr = __root.PyObject_HasAttr;
    pub const HasAttrWithError = __root.PyObject_HasAttrWithError;
    pub const HasAttrStringWithError = __root.PyObject_HasAttrStringWithError;
    pub const SelfIter = __root.PyObject_SelfIter;
    pub const GenericGetAttr = __root.PyObject_GenericGetAttr;
    pub const GenericSetAttr = __root.PyObject_GenericSetAttr;
    pub const GenericSetDict = __root.PyObject_GenericSetDict;
    pub const Hash = __root.PyObject_Hash;
    pub const HashNotImplemented = __root.PyObject_HashNotImplemented;
    pub const IsTrue = __root.PyObject_IsTrue;
    pub const Not = __root.PyObject_Not;
    pub const Check = __root.PyCallable_Check;
    pub const ClearWeakRefs = __root.PyObject_ClearWeakRefs;
    pub const Dir = __root.PyObject_Dir;
    pub const ReprEnter = __root.Py_ReprEnter;
    pub const ReprLeave = __root.Py_ReprLeave;
    pub const IsNone = __root.Py_IsNone;
    pub const NewReference = __root._Py_NewReference;
    pub const NewReferenceNoTotal = __root._Py_NewReferenceNoTotal;
    pub const ResurrectReference = __root._Py_ResurrectReference;
    pub const ForgetReference = __root._Py_ForgetReference;
    pub const Print = __root.PyObject_Print;
    pub const Dump = __root._PyObject_Dump;
    pub const GetAttrId = __root._PyObject_GetAttrId;
    pub const GetDictPtr = __root._PyObject_GetDictPtr;
    pub const CallFinalizer = __root.PyObject_CallFinalizer;
    pub const CallFinalizerFromDealloc = __root.PyObject_CallFinalizerFromDealloc;
    pub const ClearWeakRefsNoCallbacks = __root.PyUnstable_Object_ClearWeakRefsNoCallbacks;
    pub const GenericGetAttrWithDict = __root._PyObject_GenericGetAttrWithDict;
    pub const GenericSetAttrWithDict = __root._PyObject_GenericSetAttrWithDict;
    pub const FunctionStr = __root._PyObject_FunctionStr;
    pub const AssertFailed = __root._PyObject_AssertFailed;
    pub const GetItemData = __root.PyObject_GetItemData;
    pub const VisitManagedDict = __root.PyObject_VisitManagedDict;
    pub const SetManagedDict = __root._PyObject_SetManagedDict;
    pub const ClearManagedDict = __root.PyObject_ClearManagedDict;
    pub const EnableDeferredRefcount = __root.PyUnstable_Object_EnableDeferredRefcount;
    pub const IsUniqueReferencedTemporary = __root.PyUnstable_Object_IsUniqueReferencedTemporary;
    pub const IsImmortal = __root.PyUnstable_IsImmortal;
    pub const TryIncRef = __root.PyUnstable_TryIncRef;
    pub const EnableTryIncRef = __root.PyUnstable_EnableTryIncRef;
    pub const IsUniquelyReferenced = __root.PyUnstable_Object_IsUniquelyReferenced;
    pub const CheckExact = __root.PyType_CheckExact;
    pub const REFCNT = __root.Py_REFCNT;
    pub const IsStaticImmortal = __root._Py_IsStaticImmortal;
    pub const SetRefcnt = __root._Py_SetRefcnt;
    pub const Dealloc = __root._Py_Dealloc;
    pub const IncRef = __root.Py_IncRef;
    pub const DecRef = __root.Py_DecRef;
    pub const INCREF = __root.Py_INCREF;
    pub const DECREF = __root.Py_DECREF;
    pub const XINCREF = __root.Py_XINCREF;
    pub const XDECREF = __root.Py_XDECREF;
    pub const NewRef = __root.Py_NewRef;
    pub const XNewRef = __root.Py_XNewRef;
    pub const Init = __root.PyObject_Init;
    pub const IsTracked = __root.PyObject_GC_IsTracked;
    pub const IsFinalized = __root.PyObject_GC_IsFinalized;
    pub const GC = __root.PyObject_IS_GC;
    pub const LISTPTR = __root.PyObject_GET_WEAKREFS_LISTPTR;
    pub const HashDouble = __root._Py_HashDouble;
    pub const GenericHash = __root.PyObject_GenericHash;
    pub const FromObject = __root.PyByteArray_FromObject;
    pub const Concat = __root.PyByteArray_Concat;
    pub const Size = __root.PyByteArray_Size;
    pub const AsString = __root.PyByteArray_AsString;
    pub const Resize = __root.PyByteArray_Resize;
    pub const STRING = __root.PyByteArray_AS_STRING;
    pub const AsStringAndSize = __root.PyBytes_AsStringAndSize;
    pub const Join = __root.PyBytes_Join;
    pub const Substring = __root.PyUnicode_Substring;
    pub const AsUCS4 = __root.PyUnicode_AsUCS4;
    pub const AsUCS4Copy = __root.PyUnicode_AsUCS4Copy;
    pub const GetLength = __root.PyUnicode_GetLength;
    pub const ReadChar = __root.PyUnicode_ReadChar;
    pub const WriteChar = __root.PyUnicode_WriteChar;
    pub const FromEncodedObject = __root.PyUnicode_FromEncodedObject;
    pub const AsWideChar = __root.PyUnicode_AsWideChar;
    pub const AsWideCharString = __root.PyUnicode_AsWideCharString;
    pub const AsDecodedObject = __root.PyUnicode_AsDecodedObject;
    pub const AsDecodedUnicode = __root.PyUnicode_AsDecodedUnicode;
    pub const AsEncodedObject = __root.PyUnicode_AsEncodedObject;
    pub const AsEncodedString = __root.PyUnicode_AsEncodedString;
    pub const AsEncodedUnicode = __root.PyUnicode_AsEncodedUnicode;
    pub const BuildEncodingMap = __root.PyUnicode_BuildEncodingMap;
    pub const AsUTF8String = __root.PyUnicode_AsUTF8String;
    pub const AsUTF8AndSize = __root.PyUnicode_AsUTF8AndSize;
    pub const AsUTF32String = __root.PyUnicode_AsUTF32String;
    pub const AsUTF16String = __root.PyUnicode_AsUTF16String;
    pub const AsUnicodeEscapeString = __root.PyUnicode_AsUnicodeEscapeString;
    pub const AsRawUnicodeEscapeString = __root.PyUnicode_AsRawUnicodeEscapeString;
    pub const AsLatin1String = __root.PyUnicode_AsLatin1String;
    pub const AsASCIIString = __root.PyUnicode_AsASCIIString;
    pub const AsCharmapString = __root.PyUnicode_AsCharmapString;
    pub const EncodeLocale = __root.PyUnicode_EncodeLocale;
    pub const FSConverter = __root.PyUnicode_FSConverter;
    pub const FSDecoder = __root.PyUnicode_FSDecoder;
    pub const EncodeFSDefault = __root.PyUnicode_EncodeFSDefault;
    pub const Split = __root.PyUnicode_Split;
    pub const Splitlines = __root.PyUnicode_Splitlines;
    pub const Partition = __root.PyUnicode_Partition;
    pub const RPartition = __root.PyUnicode_RPartition;
    pub const RSplit = __root.PyUnicode_RSplit;
    pub const Translate = __root.PyUnicode_Translate;
    pub const Tailmatch = __root.PyUnicode_Tailmatch;
    pub const Find = __root.PyUnicode_Find;
    pub const FindChar = __root.PyUnicode_FindChar;
    pub const Count = __root.PyUnicode_Count;
    pub const Replace = __root.PyUnicode_Replace;
    pub const Compare = __root.PyUnicode_Compare;
    pub const CompareWithASCIIString = __root.PyUnicode_CompareWithASCIIString;
    pub const EqualToUTF8 = __root.PyUnicode_EqualToUTF8;
    pub const EqualToUTF8AndSize = __root.PyUnicode_EqualToUTF8AndSize;
    pub const Equal = __root.PyUnicode_Equal;
    pub const Format = __root.PyUnicode_Format;
    pub const Contains = __root.PyUnicode_Contains;
    pub const IsIdentifier = __root.PyUnicode_IsIdentifier;
    pub const READY = __root.PyUnicode_IS_READY;
    pub const KIND = __root.PyUnicode_KIND;
    pub const DATA = __root._PyUnicode_COMPACT_DATA;
    pub const CopyCharacters = __root.PyUnicode_CopyCharacters;
    pub const Fill = __root.PyUnicode_Fill;
    pub const AsUTF8 = __root.PyUnicode_AsUTF8;
    pub const SetNone = __root.PyErr_SetNone;
    pub const SetObject = __root.PyErr_SetObject;
    pub const SetString = __root.PyErr_SetString;
    pub const Restore = __root.PyErr_Restore;
    pub const SetRaisedException = __root.PyErr_SetRaisedException;
    pub const SetHandledException = __root.PyErr_SetHandledException;
    pub const SetExcInfo = __root.PyErr_SetExcInfo;
    pub const GivenExceptionMatches = __root.PyErr_GivenExceptionMatches;
    pub const ExceptionMatches = __root.PyErr_ExceptionMatches;
    pub const SetTraceback = __root.PyException_SetTraceback;
    pub const GetTraceback = __root.PyException_GetTraceback;
    pub const GetCause = __root.PyException_GetCause;
    pub const SetCause = __root.PyException_SetCause;
    pub const GetContext = __root.PyException_GetContext;
    pub const SetContext = __root.PyException_SetContext;
    pub const GetArgs = __root.PyException_GetArgs;
    pub const SetArgs = __root.PyException_SetArgs;
    pub const Name = __root.PyExceptionClass_Name;
    pub const SetFromErrno = __root.PyErr_SetFromErrno;
    pub const SetFromErrnoWithFilenameObject = __root.PyErr_SetFromErrnoWithFilenameObject;
    pub const SetFromErrnoWithFilenameObjects = __root.PyErr_SetFromErrnoWithFilenameObjects;
    pub const SetFromErrnoWithFilename = __root.PyErr_SetFromErrnoWithFilename;
    pub const FormatV = __root.PyErr_FormatV;
    pub const SetImportErrorSubclass = __root.PyErr_SetImportErrorSubclass;
    pub const SetImportError = __root.PyErr_SetImportError;
    pub const WriteUnraisable = __root.PyErr_WriteUnraisable;
    pub const GetEncoding = __root.PyUnicodeEncodeError_GetEncoding;
    pub const GetObject = __root.PyUnicodeEncodeError_GetObject;
    pub const GetStart = __root.PyUnicodeEncodeError_GetStart;
    pub const SetStart = __root.PyUnicodeEncodeError_SetStart;
    pub const GetEnd = __root.PyUnicodeEncodeError_GetEnd;
    pub const SetEnd = __root.PyUnicodeEncodeError_SetEnd;
    pub const GetReason = __root.PyUnicodeEncodeError_GetReason;
    pub const SetReason = __root.PyUnicodeEncodeError_SetReason;
    pub const ChainExceptions1 = __root._PyErr_ChainExceptions1;
    pub const PrepReraiseStar = __root.PyUnstable_Exc_PrepReraiseStar;
    pub const SyntaxLocationObject = __root.PyErr_SyntaxLocationObject;
    pub const RangedSyntaxLocationObject = __root.PyErr_RangedSyntaxLocationObject;
    pub const ProgramTextObject = __root.PyErr_ProgramTextObject;
    pub const AsLong = __root.PyLong_AsLong;
    pub const AsLongAndOverflow = __root.PyLong_AsLongAndOverflow;
    pub const t = __root.PyLong_AsSsize_t;
    pub const AsUnsignedLong = __root.PyLong_AsUnsignedLong;
    pub const AsUnsignedLongMask = __root.PyLong_AsUnsignedLongMask;
    pub const AsInt = __root.PyLong_AsInt;
    pub const AsInt32 = __root.PyLong_AsInt32;
    pub const AsUInt32 = __root.PyLong_AsUInt32;
    pub const AsInt64 = __root.PyLong_AsInt64;
    pub const AsUInt64 = __root.PyLong_AsUInt64;
    pub const AsNativeBytes = __root.PyLong_AsNativeBytes;
    pub const AsDouble = __root.PyLong_AsDouble;
    pub const AsVoidPtr = __root.PyLong_AsVoidPtr;
    pub const AsLongLong = __root.PyLong_AsLongLong;
    pub const AsUnsignedLongLong = __root.PyLong_AsUnsignedLongLong;
    pub const AsUnsignedLongLongMask = __root.PyLong_AsUnsignedLongLongMask;
    pub const AsLongLongAndOverflow = __root.PyLong_AsLongLongAndOverflow;
    pub const FromUnicodeObject = __root.PyLong_FromUnicodeObject;
    pub const IsPositive = __root.PyLong_IsPositive;
    pub const IsNegative = __root.PyLong_IsNegative;
    pub const IsZero = __root.PyLong_IsZero;
    pub const GetSign = __root.PyLong_GetSign;
    pub const Sign = __root._PyLong_Sign;
    pub const NumBits = __root._PyLong_NumBits;
    pub const GCD = __root._PyLong_GCD;
    pub const Export = __root.PyLong_Export;
    pub const IsFalse = __root.Py_IsFalse;
    pub const FromString = __root.PyFloat_FromString;
    pub const DOUBLE = __root.PyFloat_AS_DOUBLE;
    pub const RealAsDouble = __root.PyComplex_RealAsDouble;
    pub const ImagAsDouble = __root.PyComplex_ImagAsDouble;
    pub const AsCComplex = __root.PyComplex_AsCComplex;
    pub const GetContiguous = __root.PyMemoryView_GetContiguous;
    pub const BUFFER = __root.PyMemoryView_GET_BUFFER;
    pub const BASE = __root.PyMemoryView_GET_BASE;
    pub const GetItem = __root.PyTuple_GetItem;
    pub const SetItem = __root.PyTuple_SetItem;
    pub const GetSlice = __root.PyTuple_GetSlice;
    pub const ITEM = __root.PyTuple_SET_ITEM;
    pub const GetItemRef = __root.PyList_GetItemRef;
    pub const Insert = __root.PyList_Insert;
    pub const Append = __root.PyList_Append;
    pub const SetSlice = __root.PyList_SetSlice;
    pub const Sort = __root.PyList_Sort;
    pub const Reverse = __root.PyList_Reverse;
    pub const AsTuple = __root.PyList_AsTuple;
    pub const Extend = __root.PyList_Extend;
    pub const Clear = __root.PyList_Clear;
    pub const GetItemWithError = __root.PyDict_GetItemWithError;
    pub const DelItem = __root.PyDict_DelItem;
    pub const Next = __root.PyDict_Next;
    pub const Keys = __root.PyDict_Keys;
    pub const Values = __root.PyDict_Values;
    pub const Items = __root.PyDict_Items;
    pub const Copy = __root.PyDict_Copy;
    pub const Update = __root.PyDict_Update;
    pub const Merge = __root.PyDict_Merge;
    pub const MergeFromSeq2 = __root.PyDict_MergeFromSeq2;
    pub const GetItemString = __root.PyDict_GetItemString;
    pub const SetItemString = __root.PyDict_SetItemString;
    pub const DelItemString = __root.PyDict_DelItemString;
    pub const GetItemStringRef = __root.PyDict_GetItemStringRef;
    pub const GenericGetDict = __root.PyObject_GenericGetDict;
    pub const KnownHash = __root._PyDict_GetItem_KnownHash;
    pub const GetItemStringWithError = __root._PyDict_GetItemStringWithError;
    pub const SetDefault = __root.PyDict_SetDefault;
    pub const SetDefaultRef = __root.PyDict_SetDefaultRef;
    pub const ContainsString = __root.PyDict_ContainsString;
    pub const Pop = __root.PyDict_Pop;
    pub const PopString = __root.PyDict_PopString;
    pub const New = __root.PySet_New;
    pub const Add = __root.PySet_Add;
    pub const Discard = __root.PySet_Discard;
    pub const GetFunction = __root.PyCFunction_GetFunction;
    pub const GetSelf = __root.PyCFunction_GetSelf;
    pub const GetFlags = __root.PyCFunction_GetFlags;
    pub const FUNCTION = __root.PyCFunction_GET_FUNCTION;
    pub const SELF = __root.PyCFunction_GET_SELF;
    pub const FLAGS = __root.PyCFunction_GET_FLAGS;
    pub const CLASS = __root.PyCFunction_GET_CLASS;
    pub const NewObject = __root.PyModule_NewObject;
    pub const GetDict = __root.PyModule_GetDict;
    pub const GetNameObject = __root.PyModule_GetNameObject;
    pub const GetName = __root.PyModule_GetName;
    pub const GetFilename = __root.PyModule_GetFilename;
    pub const GetFilenameObject = __root.PyModule_GetFilenameObject;
    pub const GetDef = __root.PyModule_GetDef;
    pub const GetState = __root.PyModule_GetState;
    pub const NewWithQualName = __root.PyFunction_NewWithQualName;
    pub const GetCode = __root.PyFunction_GetCode;
    pub const GetGlobals = __root.PyFunction_GetGlobals;
    pub const GetModule = __root.PyFunction_GetModule;
    pub const GetDefaults = __root.PyFunction_GetDefaults;
    pub const SetDefaults = __root.PyFunction_SetDefaults;
    pub const GetKwDefaults = __root.PyFunction_GetKwDefaults;
    pub const SetKwDefaults = __root.PyFunction_SetKwDefaults;
    pub const GetClosure = __root.PyFunction_GetClosure;
    pub const SetClosure = __root.PyFunction_SetClosure;
    pub const GetAnnotations = __root.PyFunction_GetAnnotations;
    pub const SetAnnotations = __root.PyFunction_SetAnnotations;
    pub const CODE = __root.PyFunction_GET_CODE;
    pub const GLOBALS = __root.PyFunction_GET_GLOBALS;
    pub const MODULE = __root.PyFunction_GET_MODULE;
    pub const DEFAULTS = __root.PyFunction_GET_DEFAULTS;
    pub const CLOSURE = __root.PyFunction_GET_CLOSURE;
    pub const ANNOTATIONS = __root.PyFunction_GET_ANNOTATIONS;
    pub const Function = __root.PyMethod_Function;
    pub const Self = __root.PyMethod_Self;
    pub const GetLine = __root.PyFile_GetLine;
    pub const WriteObject = __root.PyFile_WriteObject;
    pub const AsFileDescriptor = __root.PyObject_AsFileDescriptor;
    pub const OpenCodeObject = __root.PyFile_OpenCodeObject;
    pub const GetPointer = __root.PyCapsule_GetPointer;
    pub const GetDestructor = __root.PyCapsule_GetDestructor;
    pub const IsValid = __root.PyCapsule_IsValid;
    pub const SetPointer = __root.PyCapsule_SetPointer;
    pub const SetDestructor = __root.PyCapsule_SetDestructor;
    pub const SetName = __root.PyCapsule_SetName;
    pub const ConstantKey = __root._PyCode_ConstantKey;
    pub const Optimize = __root.PyCode_Optimize;
    pub const GetExtra = __root.PyUnstable_Code_GetExtra;
    pub const SetExtra = __root.PyUnstable_Code_SetExtra;
    pub const GetIndices = __root.PySlice_GetIndices;
    pub const GetIndicesEx = __root.PySlice_GetIndicesEx;
    pub const Unpack = __root.PySlice_Unpack;
    pub const Get = __root.PyCell_Get;
    pub const Set = __root.PyCell_Set;
    pub const GET = __root.PyCell_GET;
    pub const SET = __root.PyCell_SET;
    pub const AddModule = __root.PyState_AddModule;
    pub const IsData = __root.PyDescr_IsData;
    pub const GenericAlias = __root.Py_GenericAlias;
    pub const WarnEx = __root.PyErr_WarnEx;
    pub const WarnFormat = __root.PyErr_WarnFormat;
    pub const ResourceWarning = __root.PyErr_ResourceWarning;
    pub const WarnExplicit = __root.PyErr_WarnExplicit;
    pub const WarnExplicitObject = __root.PyErr_WarnExplicitObject;
    pub const WarnExplicitFormat = __root.PyErr_WarnExplicitFormat;
    pub const NewProxy = __root.PyWeakref_NewProxy;
    pub const GetRef = __root.PyWeakref_GetRef;
    pub const IsDead = __root.PyWeakref_IsDead;
    pub const OBJECT = __root.PyWeakref_GET_OBJECT;
    pub const Release = __root.PyPickleBuffer_Release;
    pub const Register = __root.PyCodec_Register;
    pub const Unregister = __root.PyCodec_Unregister;
    pub const Encode = __root.PyCodec_Encode;
    pub const Decode = __root.PyCodec_Decode;
    pub const StrictErrors = __root.PyCodec_StrictErrors;
    pub const IgnoreErrors = __root.PyCodec_IgnoreErrors;
    pub const ReplaceErrors = __root.PyCodec_ReplaceErrors;
    pub const XMLCharRefReplaceErrors = __root.PyCodec_XMLCharRefReplaceErrors;
    pub const BackslashReplaceErrors = __root.PyCodec_BackslashReplaceErrors;
    pub const NameReplaceErrors = __root.PyCodec_NameReplaceErrors;
    pub const Enter = __root.PyContext_Enter;
    pub const Exit = __root.PyContext_Exit;
    pub const Reset = __root.PyContextVar_Reset;
    pub const Parse = __root.PyArg_Parse;
    pub const ParseTuple = __root.PyArg_ParseTuple;
    pub const ParseTupleAndKeywords = __root.PyArg_ParseTupleAndKeywords;
    pub const VaParse = __root.PyArg_VaParse;
    pub const VaParseTupleAndKeywords = __root.PyArg_VaParseTupleAndKeywords;
    pub const ValidateKeywordArguments = __root.PyArg_ValidateKeywordArguments;
    pub const UnpackTuple = __root.PyArg_UnpackTuple;
    pub const AddObjectRef = __root.PyModule_AddObjectRef;
    pub const AddObject = __root.PyModule_AddObject;
    pub const AddIntConstant = __root.PyModule_AddIntConstant;
    pub const AddStringConstant = __root.PyModule_AddStringConstant;
    pub const AddType = __root.PyModule_AddType;
    pub const SetDocString = __root.PyModule_SetDocString;
    pub const AddFunctions = __root.PyModule_AddFunctions;
    pub const ExecDef = __root.PyModule_ExecDef;
    pub const ParseTupleAndKeywordsFast = __root._PyArg_ParseTupleAndKeywordsFast;
    pub const Display = __root.PyErr_Display;
    pub const DisplayException = __root.PyErr_DisplayException;
    pub const EvalCode = __root.PyEval_EvalCode;
    pub const EvalCodeEx = __root.PyEval_EvalCodeEx;
    pub const GetFuncName = __root.PyEval_GetFuncName;
    pub const GetFuncDesc = __root.PyEval_GetFuncDesc;
    pub const SliceIndex = __root._PyEval_SliceIndex;
    pub const SliceIndexNotNone = __root._PyEval_SliceIndexNotNone;
    pub const FSPath = __root.PyOS_FSPath;
    pub const ExecCodeModuleObject = __root.PyImport_ExecCodeModuleObject;
    pub const AddModuleObject = __root.PyImport_AddModuleObject;
    pub const ImportModuleLevelObject = __root.PyImport_ImportModuleLevelObject;
    pub const GetImporter = __root.PyImport_GetImporter;
    pub const Import = __root.PyImport_Import;
    pub const ReloadModule = __root.PyImport_ReloadModule;
    pub const ImportFrozenModuleObject = __root.PyImport_ImportFrozenModuleObject;
    pub const ImportModuleAttr = __root.PyImport_ImportModuleAttr;
    pub const CallNoArgs = __root.PyObject_CallNoArgs;
    pub const Call = __root.PyObject_Call;
    pub const CallObject = __root.PyObject_CallObject;
    pub const CallFunction = __root.PyObject_CallFunction;
    pub const CallMethod = __root.PyObject_CallMethod;
    pub const CallFunctionObjArgs = __root.PyObject_CallFunctionObjArgs;
    pub const CallMethodObjArgs = __root.PyObject_CallMethodObjArgs;
    pub const Vectorcall = __root.PyObject_Vectorcall;
    pub const VectorcallMethod = __root.PyObject_VectorcallMethod;
    pub const Type = __root.PyObject_Type;
    pub const Length = __root.PyObject_Length;
    pub const GetIter = __root.PyObject_GetIter;
    pub const GetAIter = __root.PyObject_GetAIter;
    pub const NextItem = __root.PyIter_NextItem;
    pub const Send = __root.PyIter_Send;
    pub const Subtract = __root.PyNumber_Subtract;
    pub const Multiply = __root.PyNumber_Multiply;
    pub const MatrixMultiply = __root.PyNumber_MatrixMultiply;
    pub const FloorDivide = __root.PyNumber_FloorDivide;
    pub const TrueDivide = __root.PyNumber_TrueDivide;
    pub const Remainder = __root.PyNumber_Remainder;
    pub const Divmod = __root.PyNumber_Divmod;
    pub const Power = __root.PyNumber_Power;
    pub const Negative = __root.PyNumber_Negative;
    pub const Positive = __root.PyNumber_Positive;
    pub const Absolute = __root.PyNumber_Absolute;
    pub const Invert = __root.PyNumber_Invert;
    pub const Lshift = __root.PyNumber_Lshift;
    pub const Rshift = __root.PyNumber_Rshift;
    pub const And = __root.PyNumber_And;
    pub const Xor = __root.PyNumber_Xor;
    pub const Or = __root.PyNumber_Or;
    pub const Index = __root.PyNumber_Index;
    pub const Long = __root.PyNumber_Long;
    pub const Float = __root.PyNumber_Float;
    pub const InPlaceAdd = __root.PyNumber_InPlaceAdd;
    pub const InPlaceSubtract = __root.PyNumber_InPlaceSubtract;
    pub const InPlaceMultiply = __root.PyNumber_InPlaceMultiply;
    pub const InPlaceMatrixMultiply = __root.PyNumber_InPlaceMatrixMultiply;
    pub const InPlaceFloorDivide = __root.PyNumber_InPlaceFloorDivide;
    pub const InPlaceTrueDivide = __root.PyNumber_InPlaceTrueDivide;
    pub const InPlaceRemainder = __root.PyNumber_InPlaceRemainder;
    pub const InPlacePower = __root.PyNumber_InPlacePower;
    pub const InPlaceLshift = __root.PyNumber_InPlaceLshift;
    pub const InPlaceRshift = __root.PyNumber_InPlaceRshift;
    pub const InPlaceAnd = __root.PyNumber_InPlaceAnd;
    pub const InPlaceXor = __root.PyNumber_InPlaceXor;
    pub const InPlaceOr = __root.PyNumber_InPlaceOr;
    pub const ToBase = __root.PyNumber_ToBase;
    pub const Repeat = __root.PySequence_Repeat;
    pub const DelSlice = __root.PySequence_DelSlice;
    pub const Tuple = __root.PySequence_Tuple;
    pub const List = __root.PySequence_List;
    pub const Fast = __root.PySequence_Fast;
    pub const In = __root.PySequence_In;
    pub const InPlaceConcat = __root.PySequence_InPlaceConcat;
    pub const InPlaceRepeat = __root.PySequence_InPlaceRepeat;
    pub const HasKeyString = __root.PyMapping_HasKeyString;
    pub const HasKey = __root.PyMapping_HasKey;
    pub const HasKeyWithError = __root.PyMapping_HasKeyWithError;
    pub const HasKeyStringWithError = __root.PyMapping_HasKeyStringWithError;
    pub const GetOptionalItem = __root.PyMapping_GetOptionalItem;
    pub const GetOptionalItemString = __root.PyMapping_GetOptionalItemString;
    pub const IsInstance = __root.PyObject_IsInstance;
    pub const IsSubclass = __root.PyObject_IsSubclass;
    pub const CallMethodId = __root._PyObject_CallMethodId;
    pub const VectorcallDict = __root.PyObject_VectorcallDict;
    pub const CallOneArg = __root.PyObject_CallOneArg;
    pub const CallMethodNoArgs = __root.PyObject_CallMethodNoArgs;
    pub const CallMethodOneArg = __root.PyObject_CallMethodOneArg;
    pub const LengthHint = __root.PyObject_LengthHint;
    pub const obj = __root._Py_fopen_obj;
};
pub const PyObject = struct__object;
pub const struct_PyModuleDef_Base = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    m_init: ?*const fn () callconv(.c) [*c]PyObject = null,
    m_index: Py_ssize_t = 0,
    m_copy: [*c]PyObject = null,
};
pub const PyModuleDef_Base = struct_PyModuleDef_Base;
pub const struct_PyModuleDef_Slot = extern struct {
    slot: c_int = 0,
    value: ?*anyopaque = null,
};
pub const PyModuleDef_Slot = struct_PyModuleDef_Slot;
pub const struct_PyModuleDef = extern struct {
    m_base: PyModuleDef_Base = @import("std").mem.zeroes(PyModuleDef_Base),
    m_name: [*c]const u8 = null,
    m_doc: [*c]const u8 = null,
    m_size: Py_ssize_t = 0,
    m_methods: [*c]PyMethodDef = null,
    m_slots: [*c]PyModuleDef_Slot = null,
    m_traverse: traverseproc = null,
    m_clear: inquiry = null,
    m_free: freefunc = null,
    pub const PyModuleDef_Init = __root.PyModuleDef_Init;
    pub const PyState_RemoveModule = __root.PyState_RemoveModule;
    pub const PyState_FindModule = __root.PyState_FindModule;
    pub const PyModule_Create2 = __root.PyModule_Create2;
    pub const PyModule_FromDefAndSpec2 = __root.PyModule_FromDefAndSpec2;
    pub const Init = __root.PyModuleDef_Init;
    pub const RemoveModule = __root.PyState_RemoveModule;
    pub const FindModule = __root.PyState_FindModule;
    pub const Create2 = __root.PyModule_Create2;
    pub const FromDefAndSpec2 = __root.PyModule_FromDefAndSpec2;
};
pub const PyModuleDef = struct_PyModuleDef;
pub const digit = u32;
pub const struct__PyLongValue = extern struct {
    lv_tag: usize = 0,
    ob_digit: [1]digit = @import("std").mem.zeroes([1]digit),
};
pub const _PyLongValue = struct__PyLongValue;
pub const struct__longobject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    long_value: _PyLongValue = @import("std").mem.zeroes(_PyLongValue),
    pub const PyUnstable_Long_IsCompact = __root.PyUnstable_Long_IsCompact;
    pub const PyUnstable_Long_CompactValue = __root.PyUnstable_Long_CompactValue;
    pub const _PyLong_AsByteArray = __root._PyLong_AsByteArray;
    pub const _PyLong_Copy = __root._PyLong_Copy;
    pub const _PyLong_IsCompact = __root._PyLong_IsCompact;
    pub const _PyLong_CompactValue = __root._PyLong_CompactValue;
    pub const IsCompact = __root.PyUnstable_Long_IsCompact;
    pub const CompactValue = __root.PyUnstable_Long_CompactValue;
    pub const AsByteArray = __root._PyLong_AsByteArray;
    pub const Copy = __root._PyLong_Copy;
};
pub const PyLongObject = struct__longobject;
pub const struct__PyCoMonitoringData_13 = opaque {};
pub const struct_PyCodeObject = extern struct {
    ob_base: PyVarObject = @import("std").mem.zeroes(PyVarObject),
    co_consts: [*c]PyObject = null,
    co_names: [*c]PyObject = null,
    co_exceptiontable: [*c]PyObject = null,
    co_flags: c_int = 0,
    co_argcount: c_int = 0,
    co_posonlyargcount: c_int = 0,
    co_kwonlyargcount: c_int = 0,
    co_stacksize: c_int = 0,
    co_firstlineno: c_int = 0,
    co_nlocalsplus: c_int = 0,
    co_framesize: c_int = 0,
    co_nlocals: c_int = 0,
    co_ncellvars: c_int = 0,
    co_nfreevars: c_int = 0,
    co_version: u32 = 0,
    co_localsplusnames: [*c]PyObject = null,
    co_localspluskinds: [*c]PyObject = null,
    co_filename: [*c]PyObject = null,
    co_name: [*c]PyObject = null,
    co_qualname: [*c]PyObject = null,
    co_linetable: [*c]PyObject = null,
    co_weakreflist: [*c]PyObject = null,
    co_executors: [*c]_PyExecutorArray = null,
    _co_cached: [*c]_PyCoCached = null,
    _co_instrumentation_version: usize = 0,
    _co_monitoring: ?*struct__PyCoMonitoringData_13 = null,
    _co_unique_id: Py_ssize_t = 0,
    _co_firsttraceable: c_int = 0,
    co_extra: ?*anyopaque = null,
    co_code_adaptive: [1]u8 = @import("std").mem.zeroes([1]u8),
    pub const PyCode_GetNumFree = __root.PyCode_GetNumFree;
    pub const PyUnstable_Code_GetFirstFree = __root.PyUnstable_Code_GetFirstFree;
    pub const PyCode_GetFirstFree = __root.PyCode_GetFirstFree;
    pub const PyCode_Addr2Line = __root.PyCode_Addr2Line;
    pub const PyCode_Addr2Location = __root.PyCode_Addr2Location;
    pub const PyCode_GetCode = __root.PyCode_GetCode;
    pub const PyCode_GetVarnames = __root.PyCode_GetVarnames;
    pub const PyCode_GetCellvars = __root.PyCode_GetCellvars;
    pub const PyCode_GetFreevars = __root.PyCode_GetFreevars;
    pub const PyUnstable_PerfTrampoline_CompileCode = __root.PyUnstable_PerfTrampoline_CompileCode;
    pub const GetNumFree = __root.PyCode_GetNumFree;
    pub const GetFirstFree = __root.PyUnstable_Code_GetFirstFree;
    pub const Addr2Line = __root.PyCode_Addr2Line;
    pub const Addr2Location = __root.PyCode_Addr2Location;
    pub const GetCode = __root.PyCode_GetCode;
    pub const GetVarnames = __root.PyCode_GetVarnames;
    pub const GetCellvars = __root.PyCode_GetCellvars;
    pub const GetFreevars = __root.PyCode_GetFreevars;
    pub const CompileCode = __root.PyUnstable_PerfTrampoline_CompileCode;
};
pub const PyCodeObject = struct_PyCodeObject;
pub const struct__frame = opaque {
    pub const PyFrame_GetLineNumber = __root.PyFrame_GetLineNumber;
    pub const PyFrame_GetCode = __root.PyFrame_GetCode;
    pub const PyFrame_GetBack = __root.PyFrame_GetBack;
    pub const PyFrame_GetLocals = __root.PyFrame_GetLocals;
    pub const PyFrame_GetGlobals = __root.PyFrame_GetGlobals;
    pub const PyFrame_GetBuiltins = __root.PyFrame_GetBuiltins;
    pub const PyFrame_GetGenerator = __root.PyFrame_GetGenerator;
    pub const PyFrame_GetLasti = __root.PyFrame_GetLasti;
    pub const PyFrame_GetVar = __root.PyFrame_GetVar;
    pub const PyFrame_GetVarString = __root.PyFrame_GetVarString;
    pub const PyTraceBack_Here = __root.PyTraceBack_Here;
    pub const PyGen_New = __root.PyGen_New;
    pub const PyGen_NewWithQualName = __root.PyGen_NewWithQualName;
    pub const PyCoro_New = __root.PyCoro_New;
    pub const PyAsyncGen_New = __root.PyAsyncGen_New;
    pub const PyEval_EvalFrame = __root.PyEval_EvalFrame;
    pub const PyEval_EvalFrameEx = __root.PyEval_EvalFrameEx;
    pub const GetLineNumber = __root.PyFrame_GetLineNumber;
    pub const GetCode = __root.PyFrame_GetCode;
    pub const GetBack = __root.PyFrame_GetBack;
    pub const GetLocals = __root.PyFrame_GetLocals;
    pub const GetGlobals = __root.PyFrame_GetGlobals;
    pub const GetBuiltins = __root.PyFrame_GetBuiltins;
    pub const GetGenerator = __root.PyFrame_GetGenerator;
    pub const GetLasti = __root.PyFrame_GetLasti;
    pub const GetVar = __root.PyFrame_GetVar;
    pub const GetVarString = __root.PyFrame_GetVarString;
    pub const Here = __root.PyTraceBack_Here;
    pub const New = __root.PyGen_New;
    pub const NewWithQualName = __root.PyGen_NewWithQualName;
    pub const EvalFrame = __root.PyEval_EvalFrame;
    pub const EvalFrameEx = __root.PyEval_EvalFrameEx;
};
pub const PyFrameObject = struct__frame;
pub const PyThreadState = struct__ts;
pub const struct__is = opaque {
    pub const PyInterpreterState_Clear = __root.PyInterpreterState_Clear;
    pub const PyInterpreterState_Delete = __root.PyInterpreterState_Delete;
    pub const PyInterpreterState_GetDict = __root.PyInterpreterState_GetDict;
    pub const PyInterpreterState_GetID = __root.PyInterpreterState_GetID;
    pub const PyThreadState_New = __root.PyThreadState_New;
    pub const _PyInterpreterState_RequiresIDRef = __root._PyInterpreterState_RequiresIDRef;
    pub const _PyInterpreterState_RequireIDRef = __root._PyInterpreterState_RequireIDRef;
    pub const PyInterpreterState_Next = __root.PyInterpreterState_Next;
    pub const PyInterpreterState_ThreadHead = __root.PyInterpreterState_ThreadHead;
    pub const _PyInterpreterState_GetEvalFrameFunc = __root._PyInterpreterState_GetEvalFrameFunc;
    pub const _PyInterpreterState_SetEvalFrameFunc = __root._PyInterpreterState_SetEvalFrameFunc;
    pub const PyUnstable_AtExit = __root.PyUnstable_AtExit;
    pub const Clear = __root.PyInterpreterState_Clear;
    pub const Delete = __root.PyInterpreterState_Delete;
    pub const GetDict = __root.PyInterpreterState_GetDict;
    pub const GetID = __root.PyInterpreterState_GetID;
    pub const New = __root.PyThreadState_New;
    pub const RequiresIDRef = __root._PyInterpreterState_RequiresIDRef;
    pub const RequireIDRef = __root._PyInterpreterState_RequireIDRef;
    pub const Next = __root.PyInterpreterState_Next;
    pub const ThreadHead = __root.PyInterpreterState_ThreadHead;
    pub const GetEvalFrameFunc = __root._PyInterpreterState_GetEvalFrameFunc;
    pub const SetEvalFrameFunc = __root._PyInterpreterState_SetEvalFrameFunc;
    pub const AtExit = __root.PyUnstable_AtExit;
};
pub const PyInterpreterState = struct__is; // /usr/include/python3.14/cpython/pystate.h:83:22: warning: struct demoted to opaque type - has bitfield
const struct_unnamed_14 = opaque {}; // /usr/include/python3.14/cpython/pystate.h:101:7: warning: struct demoted to opaque type - has opaque field
pub const struct__ts = opaque {
    pub const _PyTrash_thread_deposit_object = __root._PyTrash_thread_deposit_object;
    pub const _PyTrash_thread_destroy_chain = __root._PyTrash_thread_destroy_chain;
    pub const _Py_ReachedRecursionLimitWithMargin = __root._Py_ReachedRecursionLimitWithMargin;
    pub const PyThreadState_Clear = __root.PyThreadState_Clear;
    pub const PyThreadState_Delete = __root.PyThreadState_Delete;
    pub const PyThreadState_Swap = __root.PyThreadState_Swap;
    pub const PyThreadState_GetInterpreter = __root.PyThreadState_GetInterpreter;
    pub const PyThreadState_GetFrame = __root.PyThreadState_GetFrame;
    pub const PyThreadState_GetID = __root.PyThreadState_GetID;
    pub const PyThreadState_EnterTracing = __root.PyThreadState_EnterTracing;
    pub const PyThreadState_LeaveTracing = __root.PyThreadState_LeaveTracing;
    pub const PyUnstable_ThreadState_SetStackProtection = __root.PyUnstable_ThreadState_SetStackProtection;
    pub const PyUnstable_ThreadState_ResetStackProtection = __root.PyUnstable_ThreadState_ResetStackProtection;
    pub const PyThreadState_Next = __root.PyThreadState_Next;
    pub const Py_EndInterpreter = __root.Py_EndInterpreter;
    pub const PyEval_RestoreThread = __root.PyEval_RestoreThread;
    pub const PyEval_AcquireThread = __root.PyEval_AcquireThread;
    pub const PyEval_ReleaseThread = __root.PyEval_ReleaseThread;
    pub const _PyEval_EvalFrameDefault = __root._PyEval_EvalFrameDefault;
    pub const object = __root._PyTrash_thread_deposit_object;
    pub const chain = __root._PyTrash_thread_destroy_chain;
    pub const ReachedRecursionLimitWithMargin = __root._Py_ReachedRecursionLimitWithMargin;
    pub const Clear = __root.PyThreadState_Clear;
    pub const Delete = __root.PyThreadState_Delete;
    pub const Swap = __root.PyThreadState_Swap;
    pub const GetInterpreter = __root.PyThreadState_GetInterpreter;
    pub const GetFrame = __root.PyThreadState_GetFrame;
    pub const GetID = __root.PyThreadState_GetID;
    pub const EnterTracing = __root.PyThreadState_EnterTracing;
    pub const LeaveTracing = __root.PyThreadState_LeaveTracing;
    pub const SetStackProtection = __root.PyUnstable_ThreadState_SetStackProtection;
    pub const ResetStackProtection = __root.PyUnstable_ThreadState_ResetStackProtection;
    pub const Next = __root.PyThreadState_Next;
    pub const EndInterpreter = __root.Py_EndInterpreter;
    pub const RestoreThread = __root.PyEval_RestoreThread;
    pub const AcquireThread = __root.PyEval_AcquireThread;
    pub const ReleaseThread = __root.PyEval_ReleaseThread;
    pub const EvalFrameDefault = __root._PyEval_EvalFrameDefault;
};
pub const Py_buffer = extern struct {
    buf: ?*anyopaque = null,
    obj: [*c]PyObject = null,
    len: Py_ssize_t = 0,
    itemsize: Py_ssize_t = 0,
    readonly: c_int = 0,
    ndim: c_int = 0,
    format: [*c]u8 = null,
    shape: [*c]Py_ssize_t = null,
    strides: [*c]Py_ssize_t = null,
    suboffsets: [*c]Py_ssize_t = null,
    internal: ?*anyopaque = null,
    pub const PyBuffer_GetPointer = __root.PyBuffer_GetPointer;
    pub const PyBuffer_FromContiguous = __root.PyBuffer_FromContiguous;
    pub const PyBuffer_IsContiguous = __root.PyBuffer_IsContiguous;
    pub const PyBuffer_FillInfo = __root.PyBuffer_FillInfo;
    pub const PyBuffer_Release = __root.PyBuffer_Release;
    pub const PyMemoryView_FromBuffer = __root.PyMemoryView_FromBuffer;
    pub const GetPointer = __root.PyBuffer_GetPointer;
    pub const FromContiguous = __root.PyBuffer_FromContiguous;
    pub const IsContiguous = __root.PyBuffer_IsContiguous;
    pub const FillInfo = __root.PyBuffer_FillInfo;
    pub const Release = __root.PyBuffer_Release;
    pub const FromBuffer = __root.PyMemoryView_FromBuffer;
};
pub const getbufferproc = ?*const fn ([*c]PyObject, [*c]Py_buffer, c_int) callconv(.c) c_int;
pub const releasebufferproc = ?*const fn ([*c]PyObject, [*c]Py_buffer) callconv(.c) void;
pub extern fn PyObject_CheckBuffer(obj: [*c]PyObject) c_int;
pub extern fn PyObject_GetBuffer(obj: [*c]PyObject, view: [*c]Py_buffer, flags: c_int) c_int;
pub extern fn PyBuffer_GetPointer(view: [*c]const Py_buffer, indices: [*c]const Py_ssize_t) ?*anyopaque;
pub extern fn PyBuffer_SizeFromFormat(format: [*c]const u8) Py_ssize_t;
pub extern fn PyBuffer_ToContiguous(buf: ?*anyopaque, view: [*c]const Py_buffer, len: Py_ssize_t, order: u8) c_int;
pub extern fn PyBuffer_FromContiguous(view: [*c]const Py_buffer, buf: ?*const anyopaque, len: Py_ssize_t, order: u8) c_int;
pub extern fn PyObject_CopyData(dest: [*c]PyObject, src: [*c]PyObject) c_int;
pub extern fn PyBuffer_IsContiguous(view: [*c]const Py_buffer, fort: u8) c_int;
pub extern fn PyBuffer_FillContiguousStrides(ndims: c_int, shape: [*c]Py_ssize_t, strides: [*c]Py_ssize_t, itemsize: c_int, fort: u8) void;
pub extern fn PyBuffer_FillInfo(view: [*c]Py_buffer, o: [*c]PyObject, buf: ?*anyopaque, len: Py_ssize_t, readonly: c_int, flags: c_int) c_int;
pub extern fn PyBuffer_Release(view: [*c]Py_buffer) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:15:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:14:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_int(arg_obj: [*c]c_int, arg_value: c_int) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:19:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:18:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_int8(arg_obj: [*c]i8, arg_value: i8) callconv(.c) i8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:23:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:22:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_int16(arg_obj: [*c]i16, arg_value: i16) callconv(.c) i16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:27:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:26:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_int32(arg_obj: [*c]i32, arg_value: i32) callconv(.c) i32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:31:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:30:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_int64(arg_obj: [*c]i64, arg_value: i64) callconv(.c) i64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:35:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:34:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_intptr(arg_obj: [*c]isize, arg_value: isize) callconv(.c) isize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:39:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:38:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_uint(arg_obj: [*c]c_uint, arg_value: c_uint) callconv(.c) c_uint; // /usr/include/python3.14/cpython/pyatomic_gcc.h:43:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:42:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_uint8(arg_obj: [*c]u8, arg_value: u8) callconv(.c) u8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:47:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:46:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_uint16(arg_obj: [*c]u16, arg_value: u16) callconv(.c) u16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:51:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:50:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_uint32(arg_obj: [*c]u32, arg_value: u32) callconv(.c) u32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:55:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:54:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_uint64(arg_obj: [*c]u64, arg_value: u64) callconv(.c) u64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:59:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:58:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_uintptr(arg_obj: [*c]usize, arg_value: usize) callconv(.c) usize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:63:10: warning: TODO implement function '__atomic_fetch_add' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:62:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_add_ssize(arg_obj: [*c]Py_ssize_t, arg_value: Py_ssize_t) callconv(.c) Py_ssize_t; // /usr/include/python3.14/cpython/pyatomic_gcc.h:70:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:69:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_int(arg_obj: [*c]c_int, arg_expected: [*c]c_int, arg_desired: c_int) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:75:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:74:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_int8(arg_obj: [*c]i8, arg_expected: [*c]i8, arg_desired: i8) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:80:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:79:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_int16(arg_obj: [*c]i16, arg_expected: [*c]i16, arg_desired: i16) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:85:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:84:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_int32(arg_obj: [*c]i32, arg_expected: [*c]i32, arg_desired: i32) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:90:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:89:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_int64(arg_obj: [*c]i64, arg_expected: [*c]i64, arg_desired: i64) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:95:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:94:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_intptr(arg_obj: [*c]isize, arg_expected: [*c]isize, arg_desired: isize) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:100:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:99:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_uint(arg_obj: [*c]c_uint, arg_expected: [*c]c_uint, arg_desired: c_uint) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:105:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:104:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_uint8(arg_obj: [*c]u8, arg_expected: [*c]u8, arg_desired: u8) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:110:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:109:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_uint16(arg_obj: [*c]u16, arg_expected: [*c]u16, arg_desired: u16) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:115:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:114:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_uint32(arg_obj: [*c]u32, arg_expected: [*c]u32, arg_desired: u32) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:120:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:119:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_uint64(arg_obj: [*c]u64, arg_expected: [*c]u64, arg_desired: u64) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:125:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:124:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_uintptr(arg_obj: [*c]usize, arg_expected: [*c]usize, arg_desired: usize) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:130:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:129:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_ssize(arg_obj: [*c]Py_ssize_t, arg_expected: [*c]Py_ssize_t, arg_desired: Py_ssize_t) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:135:10: warning: TODO implement function '__atomic_compare_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:134:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_compare_exchange_ptr(arg_obj: ?*anyopaque, arg_expected: ?*anyopaque, arg_desired: ?*anyopaque) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:143:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:142:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_int(arg_obj: [*c]c_int, arg_value: c_int) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:147:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:146:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_int8(arg_obj: [*c]i8, arg_value: i8) callconv(.c) i8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:151:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:150:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_int16(arg_obj: [*c]i16, arg_value: i16) callconv(.c) i16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:155:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:154:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_int32(arg_obj: [*c]i32, arg_value: i32) callconv(.c) i32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:159:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:158:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_int64(arg_obj: [*c]i64, arg_value: i64) callconv(.c) i64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:163:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:162:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_intptr(arg_obj: [*c]isize, arg_value: isize) callconv(.c) isize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:167:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:166:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_uint(arg_obj: [*c]c_uint, arg_value: c_uint) callconv(.c) c_uint; // /usr/include/python3.14/cpython/pyatomic_gcc.h:171:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:170:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_uint8(arg_obj: [*c]u8, arg_value: u8) callconv(.c) u8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:175:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:174:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_uint16(arg_obj: [*c]u16, arg_value: u16) callconv(.c) u16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:179:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:178:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_uint32(arg_obj: [*c]u32, arg_value: u32) callconv(.c) u32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:183:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:182:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_uint64(arg_obj: [*c]u64, arg_value: u64) callconv(.c) u64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:187:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:186:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_uintptr(arg_obj: [*c]usize, arg_value: usize) callconv(.c) usize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:191:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:190:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_ssize(arg_obj: [*c]Py_ssize_t, arg_value: Py_ssize_t) callconv(.c) Py_ssize_t; // /usr/include/python3.14/cpython/pyatomic_gcc.h:195:10: warning: TODO implement function '__atomic_exchange_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:194:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_exchange_ptr(arg_obj: ?*anyopaque, arg_value: ?*anyopaque) callconv(.c) ?*anyopaque; // /usr/include/python3.14/cpython/pyatomic_gcc.h:202:10: warning: TODO implement function '__atomic_fetch_and' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:201:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_and_uint8(arg_obj: [*c]u8, arg_value: u8) callconv(.c) u8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:206:10: warning: TODO implement function '__atomic_fetch_and' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:205:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_and_uint16(arg_obj: [*c]u16, arg_value: u16) callconv(.c) u16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:210:10: warning: TODO implement function '__atomic_fetch_and' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:209:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_and_uint32(arg_obj: [*c]u32, arg_value: u32) callconv(.c) u32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:214:10: warning: TODO implement function '__atomic_fetch_and' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:213:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_and_uint64(arg_obj: [*c]u64, arg_value: u64) callconv(.c) u64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:218:10: warning: TODO implement function '__atomic_fetch_and' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:217:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_and_uintptr(arg_obj: [*c]usize, arg_value: usize) callconv(.c) usize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:225:10: warning: TODO implement function '__atomic_fetch_or' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:224:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_or_uint8(arg_obj: [*c]u8, arg_value: u8) callconv(.c) u8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:229:10: warning: TODO implement function '__atomic_fetch_or' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:228:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_or_uint16(arg_obj: [*c]u16, arg_value: u16) callconv(.c) u16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:233:10: warning: TODO implement function '__atomic_fetch_or' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:232:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_or_uint32(arg_obj: [*c]u32, arg_value: u32) callconv(.c) u32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:237:10: warning: TODO implement function '__atomic_fetch_or' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:236:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_or_uint64(arg_obj: [*c]u64, arg_value: u64) callconv(.c) u64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:241:10: warning: TODO implement function '__atomic_fetch_or' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:240:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_or_uintptr(arg_obj: [*c]usize, arg_value: usize) callconv(.c) usize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:248:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:247:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int(arg_obj: [*c]const c_int) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:252:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:251:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int8(arg_obj: [*c]const i8) callconv(.c) i8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:256:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:255:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int16(arg_obj: [*c]const i16) callconv(.c) i16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:260:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:259:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int32(arg_obj: [*c]const i32) callconv(.c) i32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:264:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:263:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int64(arg_obj: [*c]const i64) callconv(.c) i64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:268:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:267:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_intptr(arg_obj: [*c]const isize) callconv(.c) isize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:272:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:271:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint8(arg_obj: [*c]const u8) callconv(.c) u8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:276:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:275:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint16(arg_obj: [*c]const u16) callconv(.c) u16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:280:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:279:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint32(arg_obj: [*c]const u32) callconv(.c) u32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:284:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:283:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint64(arg_obj: [*c]const u64) callconv(.c) u64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:288:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:287:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uintptr(arg_obj: [*c]const usize) callconv(.c) usize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:292:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:291:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint(arg_obj: [*c]const c_uint) callconv(.c) c_uint; // /usr/include/python3.14/cpython/pyatomic_gcc.h:296:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:295:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_ssize(arg_obj: [*c]const Py_ssize_t) callconv(.c) Py_ssize_t; // /usr/include/python3.14/cpython/pyatomic_gcc.h:300:18: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:299:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_ptr(arg_obj: ?*const anyopaque) callconv(.c) ?*anyopaque; // /usr/include/python3.14/cpython/pyatomic_gcc.h:307:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:306:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int_relaxed(arg_obj: [*c]const c_int) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:311:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:310:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_char_relaxed(arg_obj: [*c]const u8) callconv(.c) u8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:315:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:314:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uchar_relaxed(arg_obj: [*c]const u8) callconv(.c) u8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:319:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:318:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_short_relaxed(arg_obj: [*c]const c_short) callconv(.c) c_short; // /usr/include/python3.14/cpython/pyatomic_gcc.h:323:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:322:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_ushort_relaxed(arg_obj: [*c]const c_ushort) callconv(.c) c_ushort; // /usr/include/python3.14/cpython/pyatomic_gcc.h:327:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:326:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_long_relaxed(arg_obj: [*c]const c_long) callconv(.c) c_long; // /usr/include/python3.14/cpython/pyatomic_gcc.h:335:15: warning: TODO implement function '__atomic_load' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:334:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_double_relaxed(arg_obj: [*c]const f64) callconv(.c) f64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:395:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:394:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_llong_relaxed(arg_obj: [*c]const c_longlong) callconv(.c) c_longlong; // /usr/include/python3.14/cpython/pyatomic_gcc.h:339:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:338:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int8_relaxed(arg_obj: [*c]const i8) callconv(.c) i8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:343:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:342:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int16_relaxed(arg_obj: [*c]const i16) callconv(.c) i16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:347:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:346:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int32_relaxed(arg_obj: [*c]const i32) callconv(.c) i32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:351:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:350:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int64_relaxed(arg_obj: [*c]const i64) callconv(.c) i64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:355:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:354:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_intptr_relaxed(arg_obj: [*c]const isize) callconv(.c) isize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:359:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:358:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint8_relaxed(arg_obj: [*c]const u8) callconv(.c) u8; // /usr/include/python3.14/cpython/pyatomic_gcc.h:363:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:362:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint16_relaxed(arg_obj: [*c]const u16) callconv(.c) u16; // /usr/include/python3.14/cpython/pyatomic_gcc.h:367:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:366:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint32_relaxed(arg_obj: [*c]const u32) callconv(.c) u32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:371:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:370:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint64_relaxed(arg_obj: [*c]const u64) callconv(.c) u64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:375:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:374:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uintptr_relaxed(arg_obj: [*c]const usize) callconv(.c) usize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:379:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:378:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint_relaxed(arg_obj: [*c]const c_uint) callconv(.c) c_uint; // /usr/include/python3.14/cpython/pyatomic_gcc.h:383:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:382:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_ssize_relaxed(arg_obj: [*c]const Py_ssize_t) callconv(.c) Py_ssize_t; // /usr/include/python3.14/cpython/pyatomic_gcc.h:387:18: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:386:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_ptr_relaxed(arg_obj: ?*const anyopaque) callconv(.c) ?*anyopaque; // /usr/include/python3.14/cpython/pyatomic_gcc.h:391:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:390:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_ullong_relaxed(arg_obj: [*c]const c_ulonglong) callconv(.c) c_ulonglong; // /usr/include/python3.14/cpython/pyatomic_gcc.h:402:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:401:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int(arg_obj: [*c]c_int, arg_value: c_int) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:406:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:405:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int8(arg_obj: [*c]i8, arg_value: i8) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:410:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:409:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int16(arg_obj: [*c]i16, arg_value: i16) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:414:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:413:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int32(arg_obj: [*c]i32, arg_value: i32) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:418:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:417:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int64(arg_obj: [*c]i64, arg_value: i64) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:422:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:421:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_intptr(arg_obj: [*c]isize, arg_value: isize) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:426:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:425:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint8(arg_obj: [*c]u8, arg_value: u8) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:430:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:429:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint16(arg_obj: [*c]u16, arg_value: u16) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:434:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:433:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint32(arg_obj: [*c]u32, arg_value: u32) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:438:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:437:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint64(arg_obj: [*c]u64, arg_value: u64) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:442:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:441:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uintptr(arg_obj: [*c]usize, arg_value: usize) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:446:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:445:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint(arg_obj: [*c]c_uint, arg_value: c_uint) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:450:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:449:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_ptr(arg_obj: ?*anyopaque, arg_value: ?*anyopaque) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:454:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:453:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_ssize(arg_obj: [*c]Py_ssize_t, arg_value: Py_ssize_t) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:461:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:460:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int_relaxed(arg_obj: [*c]c_int, arg_value: c_int) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:465:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:464:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int8_relaxed(arg_obj: [*c]i8, arg_value: i8) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:469:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:468:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int16_relaxed(arg_obj: [*c]i16, arg_value: i16) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:473:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:472:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int32_relaxed(arg_obj: [*c]i32, arg_value: i32) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:477:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:476:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int64_relaxed(arg_obj: [*c]i64, arg_value: i64) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:481:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:480:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_intptr_relaxed(arg_obj: [*c]isize, arg_value: isize) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:485:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:484:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint8_relaxed(arg_obj: [*c]u8, arg_value: u8) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:489:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:488:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint16_relaxed(arg_obj: [*c]u16, arg_value: u16) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:493:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:492:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint32_relaxed(arg_obj: [*c]u32, arg_value: u32) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:497:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:496:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint64_relaxed(arg_obj: [*c]u64, arg_value: u64) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:501:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:500:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uintptr_relaxed(arg_obj: [*c]usize, arg_value: usize) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:505:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:504:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint_relaxed(arg_obj: [*c]c_uint, arg_value: c_uint) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:509:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:508:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_ptr_relaxed(arg_obj: ?*anyopaque, arg_value: ?*anyopaque) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:513:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:512:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_ssize_relaxed(arg_obj: [*c]Py_ssize_t, arg_value: Py_ssize_t) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:518:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:516:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_ullong_relaxed(arg_obj: [*c]c_ulonglong, arg_value: c_ulonglong) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:522:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:521:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_char_relaxed(arg_obj: [*c]u8, arg_value: u8) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:526:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:525:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uchar_relaxed(arg_obj: [*c]u8, arg_value: u8) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:530:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:529:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_short_relaxed(arg_obj: [*c]c_short, arg_value: c_short) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:534:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:533:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_ushort_relaxed(arg_obj: [*c]c_ushort, arg_value: c_ushort) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:538:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:537:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_long_relaxed(arg_obj: [*c]c_long, arg_value: c_long) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:542:3: warning: TODO implement function '__atomic_store' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:541:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_float_relaxed(arg_obj: [*c]f32, arg_value: f32) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:546:3: warning: TODO implement function '__atomic_store' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:545:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_double_relaxed(arg_obj: [*c]f64, arg_value: f64) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:550:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:549:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_llong_relaxed(arg_obj: [*c]c_longlong, arg_value: c_longlong) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:557:18: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:556:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_ptr_acquire(arg_obj: ?*const anyopaque) callconv(.c) ?*anyopaque; // /usr/include/python3.14/cpython/pyatomic_gcc.h:561:21: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:560:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uintptr_acquire(arg_obj: [*c]const usize) callconv(.c) usize; // /usr/include/python3.14/cpython/pyatomic_gcc.h:565:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:564:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_ptr_release(arg_obj: ?*anyopaque, arg_value: ?*anyopaque) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:569:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:568:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uintptr_release(arg_obj: [*c]usize, arg_value: usize) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:577:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:576:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_ssize_release(arg_obj: [*c]Py_ssize_t, arg_value: Py_ssize_t) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:573:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:572:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_int_release(arg_obj: [*c]c_int, arg_value: c_int) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:581:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:580:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_int_acquire(arg_obj: [*c]const c_int) callconv(.c) c_int; // /usr/include/python3.14/cpython/pyatomic_gcc.h:585:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:584:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint32_release(arg_obj: [*c]u32, arg_value: u32) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:589:3: warning: TODO implement function '__atomic_store_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:588:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_store_uint64_release(arg_obj: [*c]u64, arg_value: u64) callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:593:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:592:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint64_acquire(arg_obj: [*c]const u64) callconv(.c) u64; // /usr/include/python3.14/cpython/pyatomic_gcc.h:597:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:596:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_uint32_acquire(arg_obj: [*c]const u32) callconv(.c) u32; // /usr/include/python3.14/cpython/pyatomic_gcc.h:601:10: warning: TODO implement function '__atomic_load_n' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:600:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_ssize_acquire(arg_obj: [*c]const Py_ssize_t) callconv(.c) Py_ssize_t; // /usr/include/python3.14/cpython/pyatomic_gcc.h:607:3: warning: TODO implement function '__atomic_thread_fence' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:606:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_fence_seq_cst() callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:611:3: warning: TODO implement function '__atomic_thread_fence' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:610:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_fence_acquire() callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:615:3: warning: TODO implement function '__atomic_thread_fence' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:614:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_fence_release() callconv(.c) void; // /usr/include/python3.14/cpython/pyatomic_gcc.h:331:14: warning: TODO implement function '__atomic_load' in std.zig.c_builtins
// /usr/include/python3.14/cpython/pyatomic_gcc.h:330:1: warning: unable to translate function, demoted to extern
pub extern fn _Py_atomic_load_float_relaxed(arg_obj: [*c]const f32) callconv(.c) f32;
pub const struct_PyMutex = extern struct {
    _bits: u8 = 0,
    pub const PyMutex_Lock = __root.PyMutex_Lock;
    pub const PyMutex_Unlock = __root.PyMutex_Unlock;
    pub const PyMutex_IsLocked = __root.PyMutex_IsLocked;
    pub const _PyMutex_Lock = __root._PyMutex_Lock;
    pub const _PyMutex_Unlock = __root._PyMutex_Unlock;
    pub const _PyMutex_IsLocked = __root._PyMutex_IsLocked;
    pub const Lock = __root.PyMutex_Lock;
    pub const Unlock = __root.PyMutex_Unlock;
    pub const IsLocked = __root.PyMutex_IsLocked;
};
pub const PyMutex = struct_PyMutex;
pub extern fn PyMutex_Lock(m: [*c]PyMutex) void;
pub extern fn PyMutex_Unlock(m: [*c]PyMutex) void;
pub extern fn PyMutex_IsLocked(m: [*c]PyMutex) c_int;
pub fn _PyMutex_Lock(arg_m: [*c]PyMutex) callconv(.c) void {
    var m = arg_m;
    _ = &m;
    var expected: u8 = _Py_UNLOCKED;
    _ = &expected;
    if (!(_Py_atomic_compare_exchange_uint8(&m.*._bits, &expected, _Py_LOCKED) != 0)) {
        PyMutex_Lock(m);
    }
}
pub fn _PyMutex_Unlock(arg_m: [*c]PyMutex) callconv(.c) void {
    var m = arg_m;
    _ = &m;
    var expected: u8 = _Py_LOCKED;
    _ = &expected;
    if (!(_Py_atomic_compare_exchange_uint8(&m.*._bits, &expected, _Py_UNLOCKED) != 0)) {
        PyMutex_Unlock(m);
    }
}
pub fn _PyMutex_IsLocked(arg_m: [*c]PyMutex) callconv(.c) c_int {
    var m = arg_m;
    _ = &m;
    return @intFromBool((@as(c_int, _Py_atomic_load_uint8(&m.*._bits)) & _Py_LOCKED) != @as(c_int, 0));
}
pub const struct_PyCriticalSection = opaque {
    pub const PyCriticalSection_Begin = __root.PyCriticalSection_Begin;
    pub const PyCriticalSection_BeginMutex = __root.PyCriticalSection_BeginMutex;
    pub const PyCriticalSection_End = __root.PyCriticalSection_End;
    pub const Begin = __root.PyCriticalSection_Begin;
    pub const BeginMutex = __root.PyCriticalSection_BeginMutex;
    pub const End = __root.PyCriticalSection_End;
};
pub const PyCriticalSection = struct_PyCriticalSection;
pub const struct_PyCriticalSection2 = opaque {
    pub const PyCriticalSection2_Begin = __root.PyCriticalSection2_Begin;
    pub const PyCriticalSection2_BeginMutex = __root.PyCriticalSection2_BeginMutex;
    pub const PyCriticalSection2_End = __root.PyCriticalSection2_End;
    pub const Begin = __root.PyCriticalSection2_Begin;
    pub const BeginMutex = __root.PyCriticalSection2_BeginMutex;
    pub const End = __root.PyCriticalSection2_End;
};
pub const PyCriticalSection2 = struct_PyCriticalSection2;
pub extern fn PyCriticalSection_Begin(c: ?*PyCriticalSection, op: [*c]PyObject) void;
pub extern fn PyCriticalSection_BeginMutex(c: ?*PyCriticalSection, m: [*c]PyMutex) void;
pub extern fn PyCriticalSection_End(c: ?*PyCriticalSection) void;
pub extern fn PyCriticalSection2_Begin(c: ?*PyCriticalSection2, a: [*c]PyObject, b: [*c]PyObject) void;
pub extern fn PyCriticalSection2_BeginMutex(c: ?*PyCriticalSection2, m1: [*c]PyMutex, m2: [*c]PyMutex) void;
pub extern fn PyCriticalSection2_End(c: ?*PyCriticalSection2) void;
pub const PyVarObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    ob_size: Py_ssize_t = 0,
    pub const Py_SET_SIZE = __root.Py_SET_SIZE;
    pub const PyObject_InitVar = __root.PyObject_InitVar;
    pub const _PyObject_GC_Resize = __root._PyObject_GC_Resize;
    pub const SIZE = __root.Py_SET_SIZE;
    pub const InitVar = __root.PyObject_InitVar;
    pub const Resize = __root._PyObject_GC_Resize;
};
pub extern fn Py_Is(x: [*c]PyObject, y: [*c]PyObject) c_int;
pub extern fn Py_TYPE(ob: [*c]PyObject) [*c]PyTypeObject;
pub fn _Py_TYPE(arg_ob: [*c]PyObject) callconv(.c) [*c]PyTypeObject {
    var ob = arg_ob;
    _ = &ob;
    return ob.*.ob_type;
}
pub extern var PyLong_Type: PyTypeObject;
pub extern var PyBool_Type: PyTypeObject;
pub fn Py_SIZE(arg_ob: [*c]PyObject) callconv(.c) Py_ssize_t {
    var ob = arg_ob;
    _ = &ob;
    _ = @as(c_int, 0);
    _ = @as(c_int, 0);
    return @as([*c]PyVarObject, @ptrCast(@alignCast(ob))).*.ob_size;
}
pub fn Py_IS_TYPE(arg_ob: [*c]PyObject, arg_type: [*c]PyTypeObject) callconv(.c) c_int {
    var ob = arg_ob;
    _ = &ob;
    var @"type" = arg_type;
    _ = &@"type";
    return @intFromBool(_Py_TYPE(ob) == @"type");
}
pub fn Py_SET_TYPE(arg_ob: [*c]PyObject, arg_type: [*c]PyTypeObject) callconv(.c) void {
    var ob = arg_ob;
    _ = &ob;
    var @"type" = arg_type;
    _ = &@"type";
    ob.*.ob_type = @"type";
}
pub fn Py_SET_SIZE(arg_ob: [*c]PyVarObject, arg_size: Py_ssize_t) callconv(.c) void {
    var ob = arg_ob;
    _ = &ob;
    var size = arg_size;
    _ = &size;
    _ = @as(c_int, 0);
    _ = @as(c_int, 0);
    ob.*.ob_size = size;
}
pub const unaryfunc = ?*const fn ([*c]PyObject) callconv(.c) [*c]PyObject;
pub const binaryfunc = ?*const fn ([*c]PyObject, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const lenfunc = ?*const fn ([*c]PyObject) callconv(.c) Py_ssize_t;
pub const ssizeargfunc = ?*const fn ([*c]PyObject, Py_ssize_t) callconv(.c) [*c]PyObject;
pub const ssizessizeargfunc = ?*const fn ([*c]PyObject, Py_ssize_t, Py_ssize_t) callconv(.c) [*c]PyObject;
pub const ssizeobjargproc = ?*const fn ([*c]PyObject, Py_ssize_t, [*c]PyObject) callconv(.c) c_int;
pub const ssizessizeobjargproc = ?*const fn ([*c]PyObject, Py_ssize_t, Py_ssize_t, [*c]PyObject) callconv(.c) c_int;
pub const objobjargproc = ?*const fn ([*c]PyObject, [*c]PyObject, [*c]PyObject) callconv(.c) c_int;
pub const objobjproc = ?*const fn ([*c]PyObject, [*c]PyObject) callconv(.c) c_int;
pub const PyType_Slot = extern struct {
    slot: c_int = 0,
    pfunc: ?*anyopaque = null,
};
pub const PyType_Spec = extern struct {
    name: [*c]const u8 = null,
    basicsize: c_int = 0,
    itemsize: c_int = 0,
    flags: c_uint = 0,
    slots: [*c]PyType_Slot = null,
    pub const PyType_FromSpec = __root.PyType_FromSpec;
    pub const PyType_FromSpecWithBases = __root.PyType_FromSpecWithBases;
    pub const FromSpec = __root.PyType_FromSpec;
    pub const FromSpecWithBases = __root.PyType_FromSpecWithBases;
};
pub extern fn PyType_FromSpec([*c]PyType_Spec) [*c]PyObject;
pub extern fn PyType_FromSpecWithBases([*c]PyType_Spec, [*c]PyObject) [*c]PyObject;
pub extern fn PyType_GetSlot([*c]PyTypeObject, c_int) ?*anyopaque;
pub extern fn PyType_FromModuleAndSpec([*c]PyObject, [*c]PyType_Spec, [*c]PyObject) [*c]PyObject;
pub extern fn PyType_GetModule([*c]PyTypeObject) [*c]PyObject;
pub extern fn PyType_GetModuleState([*c]PyTypeObject) ?*anyopaque;
pub extern fn PyType_GetName([*c]PyTypeObject) [*c]PyObject;
pub extern fn PyType_GetQualName([*c]PyTypeObject) [*c]PyObject;
pub extern fn PyType_GetFullyQualifiedName(@"type": [*c]PyTypeObject) [*c]PyObject;
pub extern fn PyType_GetModuleName(@"type": [*c]PyTypeObject) [*c]PyObject;
pub extern fn PyType_FromMetaclass([*c]PyTypeObject, [*c]PyObject, [*c]PyType_Spec, [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_GetTypeData(obj: [*c]PyObject, cls: [*c]PyTypeObject) ?*anyopaque;
pub extern fn PyType_GetTypeDataSize(cls: [*c]PyTypeObject) Py_ssize_t;
pub extern fn PyType_GetBaseByToken([*c]PyTypeObject, ?*anyopaque, [*c][*c]PyTypeObject) c_int;
pub extern fn PyType_IsSubtype([*c]PyTypeObject, [*c]PyTypeObject) c_int;
pub fn PyObject_TypeCheck(arg_ob: [*c]PyObject, arg_type: [*c]PyTypeObject) callconv(.c) c_int {
    var ob = arg_ob;
    _ = &ob;
    var @"type" = arg_type;
    _ = &@"type";
    return @intFromBool((Py_IS_TYPE(ob, @"type") != 0) or (PyType_IsSubtype(_Py_TYPE(ob), @"type") != 0));
}
pub extern var PyType_Type: PyTypeObject;
pub extern var PyBaseObject_Type: PyTypeObject;
pub extern var PySuper_Type: PyTypeObject;
pub extern fn PyType_GetFlags([*c]PyTypeObject) c_ulong;
pub extern fn PyType_Ready([*c]PyTypeObject) c_int;
pub extern fn PyType_GenericAlloc([*c]PyTypeObject, Py_ssize_t) [*c]PyObject;
pub extern fn PyType_GenericNew([*c]PyTypeObject, [*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyType_ClearCache() c_uint;
pub extern fn PyType_Modified([*c]PyTypeObject) void;
pub extern fn PyObject_Repr([*c]PyObject) [*c]PyObject;
pub extern fn PyObject_Str([*c]PyObject) [*c]PyObject;
pub extern fn PyObject_ASCII([*c]PyObject) [*c]PyObject;
pub extern fn PyObject_Bytes([*c]PyObject) [*c]PyObject;
pub extern fn PyObject_RichCompare([*c]PyObject, [*c]PyObject, c_int) [*c]PyObject;
pub extern fn PyObject_RichCompareBool([*c]PyObject, [*c]PyObject, c_int) c_int;
pub extern fn PyObject_GetAttrString([*c]PyObject, [*c]const u8) [*c]PyObject;
pub extern fn PyObject_SetAttrString([*c]PyObject, [*c]const u8, [*c]PyObject) c_int;
pub extern fn PyObject_DelAttrString(v: [*c]PyObject, name: [*c]const u8) c_int;
pub extern fn PyObject_HasAttrString([*c]PyObject, [*c]const u8) c_int;
pub extern fn PyObject_GetAttr([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_GetOptionalAttr([*c]PyObject, [*c]PyObject, [*c][*c]PyObject) c_int;
pub extern fn PyObject_GetOptionalAttrString([*c]PyObject, [*c]const u8, [*c][*c]PyObject) c_int;
pub extern fn PyObject_SetAttr([*c]PyObject, [*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyObject_DelAttr(v: [*c]PyObject, name: [*c]PyObject) c_int;
pub extern fn PyObject_HasAttr([*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyObject_HasAttrWithError([*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyObject_HasAttrStringWithError([*c]PyObject, [*c]const u8) c_int;
pub extern fn PyObject_SelfIter([*c]PyObject) [*c]PyObject;
pub extern fn PyObject_GenericGetAttr([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_GenericSetAttr([*c]PyObject, [*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyObject_GenericSetDict([*c]PyObject, [*c]PyObject, ?*anyopaque) c_int;
pub extern fn PyObject_Hash([*c]PyObject) Py_hash_t;
pub extern fn PyObject_HashNotImplemented([*c]PyObject) Py_hash_t;
pub extern fn PyObject_IsTrue([*c]PyObject) c_int;
pub extern fn PyObject_Not([*c]PyObject) c_int;
pub extern fn PyCallable_Check([*c]PyObject) c_int;
pub extern fn PyObject_ClearWeakRefs([*c]PyObject) void;
pub extern fn PyObject_Dir([*c]PyObject) [*c]PyObject;
pub extern fn Py_ReprEnter([*c]PyObject) c_int;
pub extern fn Py_ReprLeave([*c]PyObject) void;
pub extern fn Py_GetConstant(constant_id: c_uint) [*c]PyObject;
pub extern fn Py_GetConstantBorrowed(constant_id: c_uint) [*c]PyObject;
pub extern var _Py_NoneStruct: PyObject;
pub extern fn Py_IsNone(x: [*c]PyObject) c_int;
pub extern var _Py_NotImplementedStruct: PyObject;
pub const PYGEN_RETURN: c_int = 0;
pub const PYGEN_ERROR: c_int = -1;
pub const PYGEN_NEXT: c_int = 1;
pub const PySendResult = c_int;
pub extern fn _Py_NewReference(op: [*c]PyObject) void;
pub extern fn _Py_NewReferenceNoTotal(op: [*c]PyObject) void;
pub extern fn _Py_ResurrectReference(op: [*c]PyObject) void;
pub extern fn _Py_ForgetReference(op: [*c]PyObject) void;
const struct_unnamed_15 = extern struct {
    v: u8 = 0,
};
pub const struct__Py_Identifier = extern struct {
    string: [*c]const u8 = null,
    index: Py_ssize_t = 0,
    mutex: struct_unnamed_15 = @import("std").mem.zeroes(struct_unnamed_15),
    pub const _PyUnicode_FromId = __root._PyUnicode_FromId;
    pub const FromId = __root._PyUnicode_FromId;
};
pub const _Py_Identifier = struct__Py_Identifier;
pub const PyNumberMethods = extern struct {
    nb_add: binaryfunc = null,
    nb_subtract: binaryfunc = null,
    nb_multiply: binaryfunc = null,
    nb_remainder: binaryfunc = null,
    nb_divmod: binaryfunc = null,
    nb_power: ternaryfunc = null,
    nb_negative: unaryfunc = null,
    nb_positive: unaryfunc = null,
    nb_absolute: unaryfunc = null,
    nb_bool: inquiry = null,
    nb_invert: unaryfunc = null,
    nb_lshift: binaryfunc = null,
    nb_rshift: binaryfunc = null,
    nb_and: binaryfunc = null,
    nb_xor: binaryfunc = null,
    nb_or: binaryfunc = null,
    nb_int: unaryfunc = null,
    nb_reserved: ?*anyopaque = null,
    nb_float: unaryfunc = null,
    nb_inplace_add: binaryfunc = null,
    nb_inplace_subtract: binaryfunc = null,
    nb_inplace_multiply: binaryfunc = null,
    nb_inplace_remainder: binaryfunc = null,
    nb_inplace_power: ternaryfunc = null,
    nb_inplace_lshift: binaryfunc = null,
    nb_inplace_rshift: binaryfunc = null,
    nb_inplace_and: binaryfunc = null,
    nb_inplace_xor: binaryfunc = null,
    nb_inplace_or: binaryfunc = null,
    nb_floor_divide: binaryfunc = null,
    nb_true_divide: binaryfunc = null,
    nb_inplace_floor_divide: binaryfunc = null,
    nb_inplace_true_divide: binaryfunc = null,
    nb_index: unaryfunc = null,
    nb_matrix_multiply: binaryfunc = null,
    nb_inplace_matrix_multiply: binaryfunc = null,
};
pub const PySequenceMethods = extern struct {
    sq_length: lenfunc = null,
    sq_concat: binaryfunc = null,
    sq_repeat: ssizeargfunc = null,
    sq_item: ssizeargfunc = null,
    was_sq_slice: ?*anyopaque = null,
    sq_ass_item: ssizeobjargproc = null,
    was_sq_ass_slice: ?*anyopaque = null,
    sq_contains: objobjproc = null,
    sq_inplace_concat: binaryfunc = null,
    sq_inplace_repeat: ssizeargfunc = null,
};
pub const PyMappingMethods = extern struct {
    mp_length: lenfunc = null,
    mp_subscript: binaryfunc = null,
    mp_ass_subscript: objobjargproc = null,
};
pub const sendfunc = ?*const fn (iter: [*c]PyObject, value: [*c]PyObject, result: [*c][*c]PyObject) callconv(.c) PySendResult;
pub const PyAsyncMethods = extern struct {
    am_await: unaryfunc = null,
    am_aiter: unaryfunc = null,
    am_anext: unaryfunc = null,
    am_send: sendfunc = null,
};
pub const PyBufferProcs = extern struct {
    bf_getbuffer: getbufferproc = null,
    bf_releasebuffer: releasebufferproc = null,
};
pub const printfunc = Py_ssize_t;
pub const struct__specialization_cache = extern struct {
    getitem: [*c]PyObject = null,
    getitem_version: u32 = 0,
    init: [*c]PyObject = null,
};
pub const struct__dictkeysobject_16 = opaque {};
pub const struct__heaptypeobject = extern struct {
    ht_type: PyTypeObject = @import("std").mem.zeroes(PyTypeObject),
    as_async: PyAsyncMethods = @import("std").mem.zeroes(PyAsyncMethods),
    as_number: PyNumberMethods = @import("std").mem.zeroes(PyNumberMethods),
    as_mapping: PyMappingMethods = @import("std").mem.zeroes(PyMappingMethods),
    as_sequence: PySequenceMethods = @import("std").mem.zeroes(PySequenceMethods),
    as_buffer: PyBufferProcs = @import("std").mem.zeroes(PyBufferProcs),
    ht_name: [*c]PyObject = null,
    ht_slots: [*c]PyObject = null,
    ht_qualname: [*c]PyObject = null,
    ht_cached_keys: ?*struct__dictkeysobject_16 = null,
    ht_module: [*c]PyObject = null,
    _ht_tpname: [*c]u8 = null,
    ht_token: ?*anyopaque = null,
    _spec_cache: struct__specialization_cache = @import("std").mem.zeroes(struct__specialization_cache),
};
pub const PyHeapTypeObject = struct__heaptypeobject;
pub extern fn _PyType_Name([*c]PyTypeObject) [*c]const u8;
pub extern fn _PyType_Lookup([*c]PyTypeObject, [*c]PyObject) [*c]PyObject;
pub extern fn _PyType_LookupRef([*c]PyTypeObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyType_GetDict([*c]PyTypeObject) [*c]PyObject;
pub extern fn PyObject_Print([*c]PyObject, [*c]FILE, c_int) c_int;
pub extern fn _Py_BreakPoint() void;
pub extern fn _PyObject_Dump([*c]PyObject) void;
pub extern fn _PyObject_GetAttrId([*c]PyObject, [*c]_Py_Identifier) [*c]PyObject;
pub extern fn _PyObject_GetDictPtr([*c]PyObject) [*c][*c]PyObject;
pub extern fn PyObject_CallFinalizer([*c]PyObject) void;
pub extern fn PyObject_CallFinalizerFromDealloc([*c]PyObject) c_int;
pub extern fn PyUnstable_Object_ClearWeakRefsNoCallbacks([*c]PyObject) void;
pub extern fn _PyObject_GenericGetAttrWithDict([*c]PyObject, [*c]PyObject, [*c]PyObject, c_int) [*c]PyObject;
pub extern fn _PyObject_GenericSetAttrWithDict([*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject) c_int;
pub extern fn _PyObject_FunctionStr([*c]PyObject) [*c]PyObject;
pub extern fn _PyObject_AssertFailed(obj: [*c]PyObject, expr: [*c]const u8, msg: [*c]const u8, file: [*c]const u8, line: c_int, function: [*c]const u8) noreturn;
pub extern fn _PyTrash_thread_deposit_object(tstate: ?*PyThreadState, op: [*c]PyObject) void;
pub extern fn _PyTrash_thread_destroy_chain(tstate: ?*PyThreadState) void;
pub extern fn _Py_ReachedRecursionLimitWithMargin(tstate: ?*PyThreadState, margin_count: c_int) c_int;
pub extern fn PyObject_GetItemData(obj: [*c]PyObject) ?*anyopaque;
pub extern fn PyObject_VisitManagedDict(obj: [*c]PyObject, visit: visitproc, arg: ?*anyopaque) c_int;
pub extern fn _PyObject_SetManagedDict(obj: [*c]PyObject, new_dict: [*c]PyObject) c_int;
pub extern fn PyObject_ClearManagedDict(obj: [*c]PyObject) void;
pub const PyType_WatchCallback = ?*const fn ([*c]PyTypeObject) callconv(.c) c_int;
pub extern fn PyType_AddWatcher(callback: PyType_WatchCallback) c_int;
pub extern fn PyType_ClearWatcher(watcher_id: c_int) c_int;
pub extern fn PyType_Watch(watcher_id: c_int, @"type": [*c]PyObject) c_int;
pub extern fn PyType_Unwatch(watcher_id: c_int, @"type": [*c]PyObject) c_int;
pub extern fn PyUnstable_Type_AssignVersionTag(@"type": [*c]PyTypeObject) c_int;
pub const PyRefTracer_CREATE: c_int = 0;
pub const PyRefTracer_DESTROY: c_int = 1;
pub const PyRefTracerEvent = c_uint;
pub const PyRefTracer = ?*const fn ([*c]PyObject, event: PyRefTracerEvent, ?*anyopaque) callconv(.c) c_int;
pub extern fn PyRefTracer_SetTracer(tracer: PyRefTracer, data: ?*anyopaque) c_int;
pub extern fn PyRefTracer_GetTracer([*c]?*anyopaque) PyRefTracer;
pub extern fn PyUnstable_Object_EnableDeferredRefcount([*c]PyObject) c_int;
pub extern fn PyUnstable_Object_IsUniqueReferencedTemporary([*c]PyObject) c_int;
pub extern fn PyUnstable_IsImmortal([*c]PyObject) c_int;
pub extern fn PyUnstable_TryIncRef([*c]PyObject) c_int;
pub extern fn PyUnstable_EnableTryIncRef([*c]PyObject) void;
pub extern fn PyUnstable_Object_IsUniquelyReferenced([*c]PyObject) c_int;
pub fn PyType_HasFeature(arg_type: [*c]PyTypeObject, arg_feature: c_ulong) callconv(.c) c_int {
    var @"type" = arg_type;
    _ = &@"type";
    var feature = arg_feature;
    _ = &feature;
    var flags: c_ulong = undefined;
    _ = &flags;
    flags = @"type".*.tp_flags;
    return @intFromBool((flags & feature) != @as(c_ulong, 0));
}
pub fn PyType_Check(arg_op: [*c]PyObject) callconv(.c) c_int {
    var op = arg_op;
    _ = &op;
    return PyType_HasFeature(_Py_TYPE(op), @as(c_ulong, 1) << @intCast(@as(c_ulong, 31)));
}
pub fn PyType_CheckExact(arg_op: [*c]PyObject) callconv(.c) c_int {
    var op = arg_op;
    _ = &op;
    return Py_IS_TYPE(op, &PyType_Type);
}
pub extern fn PyType_GetModuleByDef([*c]PyTypeObject, [*c]PyModuleDef) [*c]PyObject;
pub extern fn PyType_Freeze(@"type": [*c]PyTypeObject) c_int;
pub extern fn Py_REFCNT(ob: [*c]PyObject) Py_ssize_t;
pub fn _Py_REFCNT(arg_ob: [*c]PyObject) callconv(.c) Py_ssize_t {
    var ob = arg_ob;
    _ = &ob;
    return ob.*.unnamed_0.unnamed_0.ob_refcnt;
}
pub inline fn _Py_IsImmortal(arg_op: [*c]PyObject) c_int {
    var op = arg_op;
    _ = &op;
    return @intFromBool(@as(i32, @bitCast(@as(c_uint, @truncate(op.*.unnamed_0.unnamed_0.ob_refcnt)))) < @as(c_int, 0));
}
pub inline fn _Py_IsStaticImmortal(arg_op: [*c]PyObject) c_int {
    var op = arg_op;
    _ = &op;
    return @intFromBool((@as(c_int, op.*.unnamed_0.unnamed_0.ob_flags) & _Py_STATICALLY_ALLOCATED_FLAG) != @as(c_int, 0));
}
pub extern fn _Py_SetRefcnt(ob: [*c]PyObject, refcnt: Py_ssize_t) void;
pub fn Py_SET_REFCNT(arg_ob: [*c]PyObject, arg_refcnt: Py_ssize_t) callconv(.c) void {
    var ob = arg_ob;
    _ = &ob;
    var refcnt = arg_refcnt;
    _ = &refcnt;
    _ = @as(c_int, 0);
    if (_Py_IsImmortal(ob) != 0) {
        return;
    }
    ob.*.unnamed_0.unnamed_0.ob_refcnt = @bitCast(@as(c_int, @truncate(refcnt)));
}
pub extern fn _Py_Dealloc([*c]PyObject) void;
pub extern fn Py_IncRef([*c]PyObject) void;
pub extern fn Py_DecRef([*c]PyObject) void;
pub extern fn _Py_IncRef([*c]PyObject) void;
pub extern fn _Py_DecRef([*c]PyObject) void;
pub inline fn Py_INCREF(arg_op: [*c]PyObject) void {
    var op = arg_op;
    _ = &op;
    var cur_refcnt: u32 = op.*.unnamed_0.unnamed_0.ob_refcnt;
    _ = &cur_refcnt;
    if (@as(c_ulonglong, cur_refcnt) >= (@as(c_ulonglong, 3) << @intCast(@as(c_ulonglong, 30)))) {
        _ = @as(c_int, 0);
        return;
    }
    op.*.unnamed_0.unnamed_0.ob_refcnt = cur_refcnt +% @as(u32, 1);
    _ = @as(c_int, 0);
}
pub inline fn Py_DECREF(arg_op: [*c]PyObject) void {
    var op = arg_op;
    _ = &op;
    if (_Py_IsImmortal(op) != 0) {
        _ = @as(c_int, 0);
        return;
    }
    _ = @as(c_int, 0);
    if ((blk: {
        const ref = &op.*.unnamed_0.unnamed_0.ob_refcnt;
        ref.* -%= 1;
        break :blk ref.*;
    }) == @as(u32, 0)) {
        _Py_Dealloc(op);
    }
}
pub fn Py_XINCREF(arg_op: [*c]PyObject) callconv(.c) void {
    var op = arg_op;
    _ = &op;
    if (@as(?*anyopaque, @ptrCast(@alignCast(op))) != @as(?*anyopaque, null)) {
        Py_INCREF(op);
    }
}
pub fn Py_XDECREF(arg_op: [*c]PyObject) callconv(.c) void {
    var op = arg_op;
    _ = &op;
    if (@as(?*anyopaque, @ptrCast(@alignCast(op))) != @as(?*anyopaque, null)) {
        Py_DECREF(op);
    }
}
pub extern fn Py_NewRef(obj: [*c]PyObject) [*c]PyObject;
pub extern fn Py_XNewRef(obj: [*c]PyObject) [*c]PyObject;
pub fn _Py_NewRef(arg_obj: [*c]PyObject) callconv(.c) [*c]PyObject {
    var obj = arg_obj;
    _ = &obj;
    Py_INCREF(obj);
    return obj;
}
pub fn _Py_XNewRef(arg_obj: [*c]PyObject) callconv(.c) [*c]PyObject {
    var obj = arg_obj;
    _ = &obj;
    Py_XINCREF(obj);
    return obj;
}
pub extern fn PyObject_Malloc(size: usize) ?*anyopaque;
pub extern fn PyObject_Calloc(nelem: usize, elsize: usize) ?*anyopaque;
pub extern fn PyObject_Realloc(ptr: ?*anyopaque, new_size: usize) ?*anyopaque;
pub extern fn PyObject_Free(ptr: ?*anyopaque) void;
pub extern fn PyObject_Init([*c]PyObject, [*c]PyTypeObject) [*c]PyObject;
pub extern fn PyObject_InitVar([*c]PyVarObject, [*c]PyTypeObject, Py_ssize_t) [*c]PyVarObject;
pub extern fn _PyObject_New([*c]PyTypeObject) [*c]PyObject;
pub extern fn _PyObject_NewVar([*c]PyTypeObject, Py_ssize_t) [*c]PyVarObject;
pub extern fn PyGC_Collect() Py_ssize_t;
pub extern fn PyGC_Enable() c_int;
pub extern fn PyGC_Disable() c_int;
pub extern fn PyGC_IsEnabled() c_int;
pub extern fn _PyObject_GC_Resize([*c]PyVarObject, Py_ssize_t) [*c]PyVarObject;
pub extern fn _PyObject_GC_New([*c]PyTypeObject) [*c]PyObject;
pub extern fn _PyObject_GC_NewVar([*c]PyTypeObject, Py_ssize_t) [*c]PyVarObject;
pub extern fn PyObject_GC_Track(?*anyopaque) void;
pub extern fn PyObject_GC_UnTrack(?*anyopaque) void;
pub extern fn PyObject_GC_Del(?*anyopaque) void;
pub extern fn PyObject_GC_IsTracked([*c]PyObject) c_int;
pub extern fn PyObject_GC_IsFinalized([*c]PyObject) c_int;
pub fn _PyObject_SIZE(arg_type: [*c]PyTypeObject) callconv(.c) usize {
    var @"type" = arg_type;
    _ = &@"type";
    return @as(usize, @bitCast(@as(c_long, @"type".*.tp_basicsize)));
}
pub fn _PyObject_VAR_SIZE(arg_type: [*c]PyTypeObject, arg_nitems: Py_ssize_t) callconv(.c) usize {
    var @"type" = arg_type;
    _ = &@"type";
    var nitems = arg_nitems;
    _ = &nitems;
    var size: usize = @as(usize, @bitCast(@as(c_long, @"type".*.tp_basicsize)));
    _ = &size;
    size +%= @as(usize, @bitCast(@as(c_long, nitems))) *% @as(usize, @bitCast(@as(c_long, @"type".*.tp_itemsize)));
    return (size +% @as(usize, @bitCast(@as(c_long, SIZEOF_VOID_P - @as(c_int, 1))))) & ~@as(usize, @bitCast(@as(c_long, SIZEOF_VOID_P - @as(c_int, 1))));
}
pub const PyObjectArenaAllocator = extern struct {
    ctx: ?*anyopaque = null,
    alloc: ?*const fn (ctx: ?*anyopaque, size: usize) callconv(.c) ?*anyopaque = null,
    free: ?*const fn (ctx: ?*anyopaque, ptr: ?*anyopaque, size: usize) callconv(.c) void = null,
    pub const PyObject_GetArenaAllocator = __root.PyObject_GetArenaAllocator;
    pub const PyObject_SetArenaAllocator = __root.PyObject_SetArenaAllocator;
    pub const GetArenaAllocator = __root.PyObject_GetArenaAllocator;
    pub const SetArenaAllocator = __root.PyObject_SetArenaAllocator;
};
pub extern fn PyObject_GetArenaAllocator(allocator: [*c]PyObjectArenaAllocator) void;
pub extern fn PyObject_SetArenaAllocator(allocator: [*c]PyObjectArenaAllocator) void;
pub extern fn PyObject_IS_GC(obj: [*c]PyObject) c_int;
pub extern fn PyType_SUPPORTS_WEAKREFS(@"type": [*c]PyTypeObject) c_int;
pub extern fn PyObject_GET_WEAKREFS_LISTPTR(op: [*c]PyObject) [*c][*c]PyObject;
pub extern fn PyUnstable_Object_GC_NewWithExtraData([*c]PyTypeObject, usize) [*c]PyObject;
pub const gcvisitobjects_t = ?*const fn ([*c]PyObject, ?*anyopaque) callconv(.c) c_int;
pub extern fn PyUnstable_GC_VisitObjects(callback: gcvisitobjects_t, arg: ?*anyopaque) void;
pub extern fn _Py_HashDouble([*c]PyObject, f64) Py_hash_t;
pub const PyHash_FuncDef = extern struct {
    hash: ?*const fn (?*const anyopaque, Py_ssize_t) callconv(.c) Py_hash_t = null,
    name: [*c]const u8 = null,
    hash_bits: c_int = 0,
    seed_bits: c_int = 0,
};
pub extern fn PyHash_GetFuncDef() [*c]PyHash_FuncDef;
pub extern fn Py_HashPointer(ptr: ?*const anyopaque) Py_hash_t;
pub fn _Py_HashPointer(arg_ptr: ?*const anyopaque) callconv(.c) Py_hash_t {
    var ptr = arg_ptr;
    _ = &ptr;
    return Py_HashPointer(ptr);
}
pub extern fn PyObject_GenericHash([*c]PyObject) Py_hash_t;
pub extern fn Py_HashBuffer(ptr: ?*const anyopaque, len: Py_ssize_t) Py_hash_t;
pub extern var Py_DebugFlag: c_int;
pub extern var Py_VerboseFlag: c_int;
pub extern var Py_QuietFlag: c_int;
pub extern var Py_InteractiveFlag: c_int;
pub extern var Py_InspectFlag: c_int;
pub extern var Py_OptimizeFlag: c_int;
pub extern var Py_NoSiteFlag: c_int;
pub extern var Py_BytesWarningFlag: c_int;
pub extern var Py_FrozenFlag: c_int;
pub extern var Py_IgnoreEnvironmentFlag: c_int;
pub extern var Py_DontWriteBytecodeFlag: c_int;
pub extern var Py_NoUserSiteDirectory: c_int;
pub extern var Py_UnbufferedStdioFlag: c_int;
pub extern var Py_HashRandomizationFlag: c_int;
pub extern var Py_IsolatedFlag: c_int;
pub extern fn Py_GETENV(name: [*c]const u8) [*c]u8;
pub extern var PyByteArray_Type: PyTypeObject;
pub extern var PyByteArrayIter_Type: PyTypeObject;
pub extern fn PyByteArray_FromObject([*c]PyObject) [*c]PyObject;
pub extern fn PyByteArray_Concat([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyByteArray_FromStringAndSize([*c]const u8, Py_ssize_t) [*c]PyObject;
pub extern fn PyByteArray_Size([*c]PyObject) Py_ssize_t;
pub extern fn PyByteArray_AsString([*c]PyObject) [*c]u8;
pub extern fn PyByteArray_Resize([*c]PyObject, Py_ssize_t) c_int;
pub const PyByteArrayObject = extern struct {
    ob_base: PyVarObject = @import("std").mem.zeroes(PyVarObject),
    ob_alloc: Py_ssize_t = 0,
    ob_bytes: [*c]u8 = null,
    ob_start: [*c]u8 = null,
    ob_exports: Py_ssize_t = 0,
};
pub const _PyByteArray_empty_string: [*c]u8 = @extern([*c]u8, .{
    .name = "_PyByteArray_empty_string",
});
pub fn PyByteArray_AS_STRING(arg_op: [*c]PyObject) callconv(.c) [*c]u8 {
    var op = arg_op;
    _ = &op;
    var self: [*c]PyByteArrayObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyByteArrayObject, @ptrCast(@alignCast(op)));
    };
    _ = &self;
    if (Py_SIZE(@as([*c]PyObject, @ptrCast(@alignCast(self)))) != 0) {
        return self.*.ob_start;
    }
    return _PyByteArray_empty_string;
}
pub fn PyByteArray_GET_SIZE(arg_op: [*c]PyObject) callconv(.c) Py_ssize_t {
    var op = arg_op;
    _ = &op;
    var self: [*c]PyByteArrayObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyByteArrayObject, @ptrCast(@alignCast(op)));
    };
    _ = &self;
    return Py_SIZE(@as([*c]PyObject, @ptrCast(@alignCast(self))));
}
pub extern var PyBytes_Type: PyTypeObject;
pub extern var PyBytesIter_Type: PyTypeObject;
pub extern fn PyBytes_FromStringAndSize([*c]const u8, Py_ssize_t) [*c]PyObject;
pub extern fn PyBytes_FromString([*c]const u8) [*c]PyObject;
pub extern fn PyBytes_FromObject([*c]PyObject) [*c]PyObject;
pub extern fn PyBytes_FromFormatV([*c]const u8, [*c]struct___va_list_tag_3) [*c]PyObject;
pub extern fn PyBytes_FromFormat([*c]const u8, ...) [*c]PyObject;
pub extern fn PyBytes_Size([*c]PyObject) Py_ssize_t;
pub extern fn PyBytes_AsString([*c]PyObject) [*c]u8;
pub extern fn PyBytes_Repr([*c]PyObject, c_int) [*c]PyObject;
pub extern fn PyBytes_Concat([*c][*c]PyObject, [*c]PyObject) void;
pub extern fn PyBytes_ConcatAndDel([*c][*c]PyObject, [*c]PyObject) void;
pub extern fn PyBytes_DecodeEscape([*c]const u8, Py_ssize_t, [*c]const u8, Py_ssize_t, [*c]const u8) [*c]PyObject;
pub extern fn PyBytes_AsStringAndSize(obj: [*c]PyObject, s: [*c][*c]u8, len: [*c]Py_ssize_t) c_int;
pub const PyBytesObject = extern struct {
    ob_base: PyVarObject = @import("std").mem.zeroes(PyVarObject),
    ob_shash: Py_hash_t = 0,
    ob_sval: [1]u8 = @import("std").mem.zeroes([1]u8),
};
pub extern fn _PyBytes_Resize([*c][*c]PyObject, Py_ssize_t) c_int;
pub fn PyBytes_AS_STRING(arg_op: [*c]PyObject) callconv(.c) [*c]u8 {
    var op = arg_op;
    _ = &op;
    return @ptrCast(@alignCast(&(blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyBytesObject, @ptrCast(@alignCast(op)));
    }).*.ob_sval));
}
pub fn PyBytes_GET_SIZE(arg_op: [*c]PyObject) callconv(.c) Py_ssize_t {
    var op = arg_op;
    _ = &op;
    var self: [*c]PyBytesObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyBytesObject, @ptrCast(@alignCast(op)));
    };
    _ = &self;
    return Py_SIZE(@as([*c]PyObject, @ptrCast(@alignCast(self))));
}
pub extern fn PyBytes_Join(sep: [*c]PyObject, iterable: [*c]PyObject) [*c]PyObject;
pub fn _PyBytes_Join(arg_sep: [*c]PyObject, arg_iterable: [*c]PyObject) callconv(.c) [*c]PyObject {
    var sep = arg_sep;
    _ = &sep;
    var iterable = arg_iterable;
    _ = &iterable;
    return PyBytes_Join(sep, iterable);
}
pub const Py_UCS4 = u32;
pub const Py_UCS2 = u16;
pub const Py_UCS1 = u8;
pub extern var PyUnicode_Type: PyTypeObject;
pub extern var PyUnicodeIter_Type: PyTypeObject;
pub extern fn PyUnicode_FromStringAndSize(u: [*c]const u8, size: Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_FromString(u: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_Substring(str: [*c]PyObject, start: Py_ssize_t, end: Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_AsUCS4(unicode: [*c]PyObject, buffer: [*c]Py_UCS4, buflen: Py_ssize_t, copy_null: c_int) [*c]Py_UCS4;
pub extern fn PyUnicode_AsUCS4Copy(unicode: [*c]PyObject) [*c]Py_UCS4;
pub extern fn PyUnicode_GetLength(unicode: [*c]PyObject) Py_ssize_t;
pub extern fn PyUnicode_ReadChar(unicode: [*c]PyObject, index: Py_ssize_t) Py_UCS4;
pub extern fn PyUnicode_WriteChar(unicode: [*c]PyObject, index: Py_ssize_t, character: Py_UCS4) c_int;
pub extern fn PyUnicode_Resize(unicode: [*c][*c]PyObject, length: Py_ssize_t) c_int;
pub extern fn PyUnicode_FromEncodedObject(obj: [*c]PyObject, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_FromObject(obj: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_FromFormatV(format: [*c]const u8, vargs: [*c]struct___va_list_tag_3) [*c]PyObject;
pub extern fn PyUnicode_FromFormat(format: [*c]const u8, ...) [*c]PyObject;
pub extern fn PyUnicode_InternInPlace([*c][*c]PyObject) void;
pub extern fn PyUnicode_InternFromString(u: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_FromWideChar(w: [*c]const wchar_t, size: Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_AsWideChar(unicode: [*c]PyObject, w: [*c]wchar_t, size: Py_ssize_t) Py_ssize_t;
pub extern fn PyUnicode_AsWideCharString(unicode: [*c]PyObject, size: [*c]Py_ssize_t) [*c]wchar_t;
pub extern fn PyUnicode_FromOrdinal(ordinal: c_int) [*c]PyObject;
pub extern fn PyUnicode_GetDefaultEncoding() [*c]const u8;
pub extern fn PyUnicode_Decode(s: [*c]const u8, size: Py_ssize_t, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsDecodedObject(unicode: [*c]PyObject, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsDecodedUnicode(unicode: [*c]PyObject, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsEncodedObject(unicode: [*c]PyObject, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsEncodedString(unicode: [*c]PyObject, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsEncodedUnicode(unicode: [*c]PyObject, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_BuildEncodingMap(string: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_DecodeUTF7(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_DecodeUTF7Stateful(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8, consumed: [*c]Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_DecodeUTF8(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_DecodeUTF8Stateful(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8, consumed: [*c]Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_AsUTF8String(unicode: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_AsUTF8AndSize(unicode: [*c]PyObject, size: [*c]Py_ssize_t) [*c]const u8;
pub extern fn PyUnicode_DecodeUTF32(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8, byteorder: [*c]c_int) [*c]PyObject;
pub extern fn PyUnicode_DecodeUTF32Stateful(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8, byteorder: [*c]c_int, consumed: [*c]Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_AsUTF32String(unicode: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_DecodeUTF16(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8, byteorder: [*c]c_int) [*c]PyObject;
pub extern fn PyUnicode_DecodeUTF16Stateful(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8, byteorder: [*c]c_int, consumed: [*c]Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_AsUTF16String(unicode: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_DecodeUnicodeEscape(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsUnicodeEscapeString(unicode: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_DecodeRawUnicodeEscape(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsRawUnicodeEscapeString(unicode: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_DecodeLatin1(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsLatin1String(unicode: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_DecodeASCII(string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsASCIIString(unicode: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_DecodeCharmap(string: [*c]const u8, length: Py_ssize_t, mapping: [*c]PyObject, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_AsCharmapString(unicode: [*c]PyObject, mapping: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_DecodeLocaleAndSize(str: [*c]const u8, len: Py_ssize_t, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_DecodeLocale(str: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_EncodeLocale(unicode: [*c]PyObject, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_FSConverter([*c]PyObject, ?*anyopaque) c_int;
pub extern fn PyUnicode_FSDecoder([*c]PyObject, ?*anyopaque) c_int;
pub extern fn PyUnicode_DecodeFSDefault(s: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_DecodeFSDefaultAndSize(s: [*c]const u8, size: Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_EncodeFSDefault(unicode: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_Concat(left: [*c]PyObject, right: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_Append(pleft: [*c][*c]PyObject, right: [*c]PyObject) void;
pub extern fn PyUnicode_AppendAndDel(pleft: [*c][*c]PyObject, right: [*c]PyObject) void;
pub extern fn PyUnicode_Split(s: [*c]PyObject, sep: [*c]PyObject, maxsplit: Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_Splitlines(s: [*c]PyObject, keepends: c_int) [*c]PyObject;
pub extern fn PyUnicode_Partition(s: [*c]PyObject, sep: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_RPartition(s: [*c]PyObject, sep: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_RSplit(s: [*c]PyObject, sep: [*c]PyObject, maxsplit: Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_Translate(str: [*c]PyObject, table: [*c]PyObject, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicode_Join(separator: [*c]PyObject, seq: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_Tailmatch(str: [*c]PyObject, substr: [*c]PyObject, start: Py_ssize_t, end: Py_ssize_t, direction: c_int) Py_ssize_t;
pub extern fn PyUnicode_Find(str: [*c]PyObject, substr: [*c]PyObject, start: Py_ssize_t, end: Py_ssize_t, direction: c_int) Py_ssize_t;
pub extern fn PyUnicode_FindChar(str: [*c]PyObject, ch: Py_UCS4, start: Py_ssize_t, end: Py_ssize_t, direction: c_int) Py_ssize_t;
pub extern fn PyUnicode_Count(str: [*c]PyObject, substr: [*c]PyObject, start: Py_ssize_t, end: Py_ssize_t) Py_ssize_t;
pub extern fn PyUnicode_Replace(str: [*c]PyObject, substr: [*c]PyObject, replstr: [*c]PyObject, maxcount: Py_ssize_t) [*c]PyObject;
pub extern fn PyUnicode_Compare(left: [*c]PyObject, right: [*c]PyObject) c_int;
pub extern fn PyUnicode_CompareWithASCIIString(left: [*c]PyObject, right: [*c]const u8) c_int;
pub extern fn PyUnicode_EqualToUTF8([*c]PyObject, [*c]const u8) c_int;
pub extern fn PyUnicode_EqualToUTF8AndSize([*c]PyObject, [*c]const u8, Py_ssize_t) c_int;
pub extern fn PyUnicode_Equal(str1: [*c]PyObject, str2: [*c]PyObject) c_int;
pub extern fn PyUnicode_RichCompare(left: [*c]PyObject, right: [*c]PyObject, op: c_int) [*c]PyObject;
pub extern fn PyUnicode_Format(format: [*c]PyObject, args: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnicode_Contains(container: [*c]PyObject, element: [*c]PyObject) c_int;
pub extern fn PyUnicode_IsIdentifier(s: [*c]PyObject) c_int;
pub const PY_UNICODE_TYPE = wchar_t;
pub const Py_UNICODE = wchar_t;
pub fn Py_UNICODE_IS_SURROGATE(arg_ch: Py_UCS4) callconv(.c) c_int {
    var ch = arg_ch;
    _ = &ch;
    return @intFromBool((@as(Py_UCS4, 55296) <= ch) and (ch <= @as(Py_UCS4, 57343)));
}
pub fn Py_UNICODE_IS_HIGH_SURROGATE(arg_ch: Py_UCS4) callconv(.c) c_int {
    var ch = arg_ch;
    _ = &ch;
    return @intFromBool((@as(Py_UCS4, 55296) <= ch) and (ch <= @as(Py_UCS4, 56319)));
}
pub fn Py_UNICODE_IS_LOW_SURROGATE(arg_ch: Py_UCS4) callconv(.c) c_int {
    var ch = arg_ch;
    _ = &ch;
    return @intFromBool((@as(Py_UCS4, 56320) <= ch) and (ch <= @as(Py_UCS4, 57343)));
}
pub fn Py_UNICODE_JOIN_SURROGATES(arg_high: Py_UCS4, arg_low: Py_UCS4) callconv(.c) Py_UCS4 {
    var high = arg_high;
    _ = &high;
    var low = arg_low;
    _ = &low;
    _ = @as(c_int, 0);
    _ = @as(c_int, 0);
    return @as(Py_UCS4, 65536) +% (((high & @as(Py_UCS4, 1023)) << @intCast(@as(Py_UCS4, 10))) | (low & @as(Py_UCS4, 1023)));
}
pub fn Py_UNICODE_HIGH_SURROGATE(arg_ch: Py_UCS4) callconv(.c) Py_UCS4 {
    var ch = arg_ch;
    _ = &ch;
    _ = @as(c_int, 0);
    return @as(Py_UCS4, @bitCast(@as(c_int, @as(c_int, 55296) - (@as(c_int, 65536) >> @intCast(@as(c_int, 10)))))) +% (ch >> @intCast(@as(Py_UCS4, 10)));
}
pub fn Py_UNICODE_LOW_SURROGATE(arg_ch: Py_UCS4) callconv(.c) Py_UCS4 {
    var ch = arg_ch;
    _ = &ch;
    _ = @as(c_int, 0);
    return @as(Py_UCS4, 56320) +% (ch & @as(Py_UCS4, 1023));
} // /usr/include/python3.14/cpython/unicodeobject.h:121:22: warning: struct demoted to opaque type - has bitfield
const struct_unnamed_17 = opaque {}; // /usr/include/python3.14/cpython/unicodeobject.h:162:7: warning: struct demoted to opaque type - has opaque field
pub const PyASCIIObject = opaque {}; // /usr/include/python3.14/cpython/unicodeobject.h:169:19: warning: struct demoted to opaque type - has opaque field
pub const PyCompactUnicodeObject = opaque {}; // /usr/include/python3.14/cpython/unicodeobject.h:177:28: warning: struct demoted to opaque type - has opaque field
pub const PyUnicodeObject = opaque {}; // /usr/include/python3.14/cpython/unicodeobject.h:213:42: warning: member access of demoted record
// /usr/include/python3.14/cpython/unicodeobject.h:209:28: warning: unable to translate function, demoted to extern
pub extern fn PyUnicode_CHECK_INTERNED(arg_op: [*c]PyObject) callconv(.c) c_uint;
pub fn PyUnicode_IS_READY(arg__unused_op: [*c]PyObject) callconv(.c) c_uint {
    var _unused_op = arg__unused_op;
    _ = &_unused_op;
    return 1;
} // /usr/include/python3.14/cpython/unicodeobject.h:227:42: warning: member access of demoted record
// /usr/include/python3.14/cpython/unicodeobject.h:226:28: warning: unable to translate function, demoted to extern
pub extern fn PyUnicode_IS_ASCII(arg_op: [*c]PyObject) callconv(.c) c_uint; // /usr/include/python3.14/cpython/unicodeobject.h:234:42: warning: member access of demoted record
// /usr/include/python3.14/cpython/unicodeobject.h:233:28: warning: unable to translate function, demoted to extern
pub extern fn PyUnicode_IS_COMPACT(arg_op: [*c]PyObject) callconv(.c) c_uint; // /usr/include/python3.14/cpython/unicodeobject.h:241:43: warning: member access of demoted record
// /usr/include/python3.14/cpython/unicodeobject.h:240:19: warning: unable to translate function, demoted to extern
pub extern fn PyUnicode_IS_COMPACT_ASCII(arg_op: [*c]PyObject) callconv(.c) c_int;
pub const PyUnicode_1BYTE_KIND: c_int = 1;
pub const PyUnicode_2BYTE_KIND: c_int = 2;
pub const PyUnicode_4BYTE_KIND: c_int = 4;
pub const enum_PyUnicode_Kind = c_uint;
pub extern fn PyUnicode_KIND(op: [*c]PyObject) c_int;
pub fn _PyUnicode_COMPACT_DATA(arg_op: [*c]PyObject) callconv(.c) ?*anyopaque {
    var op = arg_op;
    _ = &op;
    if (PyUnicode_IS_ASCII(op) != 0) {
        return @as(?*anyopaque, @ptrCast(@alignCast((blk: {
            _ = @as(c_int, 0);
            break :blk @as(?*PyASCIIObject, @ptrCast(@alignCast(op)));
        }) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 1))))))));
    }
    return @as(?*anyopaque, @ptrCast(@alignCast((blk: {
        _ = @as(c_int, 0);
        break :blk @as(?*PyCompactUnicodeObject, @ptrCast(@alignCast(op)));
    }) + @as(usize, @bitCast(@as(isize, @intCast(@as(c_int, 1))))))));
} // /usr/include/python3.14/cpython/unicodeobject.h:273:37: warning: member access of demoted record
// /usr/include/python3.14/cpython/unicodeobject.h:270:21: warning: unable to translate function, demoted to extern
pub extern fn _PyUnicode_NONCOMPACT_DATA(arg_op: [*c]PyObject) callconv(.c) ?*anyopaque;
pub extern fn PyUnicode_DATA(op: [*c]PyObject) ?*anyopaque;
pub fn _PyUnicode_DATA(arg_op: [*c]PyObject) callconv(.c) ?*anyopaque {
    var op = arg_op;
    _ = &op;
    if (PyUnicode_IS_COMPACT(op) != 0) {
        return _PyUnicode_COMPACT_DATA(op);
    }
    return _PyUnicode_NONCOMPACT_DATA(op);
} // /usr/include/python3.14/cpython/unicodeobject.h:299:35: warning: member access of demoted record
// /usr/include/python3.14/cpython/unicodeobject.h:298:26: warning: unable to translate function, demoted to extern
pub extern fn PyUnicode_GET_LENGTH(arg_op: [*c]PyObject) callconv(.c) Py_ssize_t;
pub fn PyUnicode_WRITE(arg_kind: c_int, arg_data: ?*anyopaque, arg_index_1: Py_ssize_t, arg_value: Py_UCS4) callconv(.c) void {
    var kind = arg_kind;
    _ = &kind;
    var data = arg_data;
    _ = &data;
    var index_1 = arg_index_1;
    _ = &index_1;
    var value = arg_value;
    _ = &value;
    _ = @as(c_int, 0);
    if (kind == PyUnicode_1BYTE_KIND) {
        _ = @as(c_int, 0);
        @as([*c]Py_UCS1, @ptrCast(@alignCast(data)))[@bitCast(@as(isize, @intCast(index_1)))] = @as(Py_UCS1, @truncate(value));
    } else if (kind == PyUnicode_2BYTE_KIND) {
        _ = @as(c_int, 0);
        @as([*c]Py_UCS2, @ptrCast(@alignCast(data)))[@bitCast(@as(isize, @intCast(index_1)))] = @as(Py_UCS2, @truncate(value));
    } else {
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        @as([*c]Py_UCS4, @ptrCast(@alignCast(data)))[@bitCast(@as(isize, @intCast(index_1)))] = value;
    }
}
pub fn PyUnicode_READ(arg_kind: c_int, arg_data: ?*const anyopaque, arg_index_1: Py_ssize_t) callconv(.c) Py_UCS4 {
    var kind = arg_kind;
    _ = &kind;
    var data = arg_data;
    _ = &data;
    var index_1 = arg_index_1;
    _ = &index_1;
    _ = @as(c_int, 0);
    if (kind == PyUnicode_1BYTE_KIND) {
        return @as([*c]const Py_UCS1, @ptrCast(@alignCast(data)))[@bitCast(@as(isize, @intCast(index_1)))];
    }
    if (kind == PyUnicode_2BYTE_KIND) {
        return @as([*c]const Py_UCS2, @ptrCast(@alignCast(data)))[@bitCast(@as(isize, @intCast(index_1)))];
    }
    _ = @as(c_int, 0);
    return @as([*c]const Py_UCS4, @ptrCast(@alignCast(data)))[@bitCast(@as(isize, @intCast(index_1)))];
} // /usr/include/python3.14/cpython/unicodeobject.h:260:69: warning: member access of demoted record
// /usr/include/python3.14/cpython/unicodeobject.h:354:23: warning: unable to translate function, demoted to extern
pub extern fn PyUnicode_READ_CHAR(arg_unicode: [*c]PyObject, arg_index_1: Py_ssize_t) callconv(.c) Py_UCS4; // /usr/include/python3.14/cpython/unicodeobject.h:260:69: warning: member access of demoted record
// /usr/include/python3.14/cpython/unicodeobject.h:378:23: warning: unable to translate function, demoted to extern
pub extern fn PyUnicode_MAX_CHAR_VALUE(arg_op: [*c]PyObject) callconv(.c) Py_UCS4;
pub extern fn PyUnicode_New(size: Py_ssize_t, maxchar: Py_UCS4) [*c]PyObject;
pub fn PyUnicode_READY(arg__unused_op: [*c]PyObject) callconv(.c) c_int {
    var _unused_op = arg__unused_op;
    _ = &_unused_op;
    return 0;
}
pub extern fn PyUnicode_CopyCharacters(to: [*c]PyObject, to_start: Py_ssize_t, from: [*c]PyObject, from_start: Py_ssize_t, how_many: Py_ssize_t) Py_ssize_t;
pub extern fn PyUnicode_Fill(unicode: [*c]PyObject, start: Py_ssize_t, length: Py_ssize_t, fill_char: Py_UCS4) Py_ssize_t;
pub extern fn PyUnicode_FromKindAndData(kind: c_int, buffer: ?*const anyopaque, size: Py_ssize_t) [*c]PyObject;
pub const struct_PyUnicodeWriter = opaque {
    pub const PyUnicodeWriter_Discard = __root.PyUnicodeWriter_Discard;
    pub const PyUnicodeWriter_Finish = __root.PyUnicodeWriter_Finish;
    pub const PyUnicodeWriter_WriteChar = __root.PyUnicodeWriter_WriteChar;
    pub const PyUnicodeWriter_WriteUTF8 = __root.PyUnicodeWriter_WriteUTF8;
    pub const PyUnicodeWriter_WriteASCII = __root.PyUnicodeWriter_WriteASCII;
    pub const PyUnicodeWriter_WriteWideChar = __root.PyUnicodeWriter_WriteWideChar;
    pub const PyUnicodeWriter_WriteUCS4 = __root.PyUnicodeWriter_WriteUCS4;
    pub const PyUnicodeWriter_WriteStr = __root.PyUnicodeWriter_WriteStr;
    pub const PyUnicodeWriter_WriteRepr = __root.PyUnicodeWriter_WriteRepr;
    pub const PyUnicodeWriter_WriteSubstring = __root.PyUnicodeWriter_WriteSubstring;
    pub const PyUnicodeWriter_Format = __root.PyUnicodeWriter_Format;
    pub const PyUnicodeWriter_DecodeUTF8Stateful = __root.PyUnicodeWriter_DecodeUTF8Stateful;
    pub const Discard = __root.PyUnicodeWriter_Discard;
    pub const Finish = __root.PyUnicodeWriter_Finish;
    pub const WriteChar = __root.PyUnicodeWriter_WriteChar;
    pub const WriteUTF8 = __root.PyUnicodeWriter_WriteUTF8;
    pub const WriteASCII = __root.PyUnicodeWriter_WriteASCII;
    pub const WriteWideChar = __root.PyUnicodeWriter_WriteWideChar;
    pub const WriteUCS4 = __root.PyUnicodeWriter_WriteUCS4;
    pub const WriteStr = __root.PyUnicodeWriter_WriteStr;
    pub const WriteRepr = __root.PyUnicodeWriter_WriteRepr;
    pub const WriteSubstring = __root.PyUnicodeWriter_WriteSubstring;
    pub const Format = __root.PyUnicodeWriter_Format;
    pub const DecodeUTF8Stateful = __root.PyUnicodeWriter_DecodeUTF8Stateful;
};
pub const PyUnicodeWriter = struct_PyUnicodeWriter;
pub extern fn PyUnicodeWriter_Create(length: Py_ssize_t) ?*PyUnicodeWriter;
pub extern fn PyUnicodeWriter_Discard(writer: ?*PyUnicodeWriter) void;
pub extern fn PyUnicodeWriter_Finish(writer: ?*PyUnicodeWriter) [*c]PyObject;
pub extern fn PyUnicodeWriter_WriteChar(writer: ?*PyUnicodeWriter, ch: Py_UCS4) c_int;
pub extern fn PyUnicodeWriter_WriteUTF8(writer: ?*PyUnicodeWriter, str: [*c]const u8, size: Py_ssize_t) c_int;
pub extern fn PyUnicodeWriter_WriteASCII(writer: ?*PyUnicodeWriter, str: [*c]const u8, size: Py_ssize_t) c_int;
pub extern fn PyUnicodeWriter_WriteWideChar(writer: ?*PyUnicodeWriter, str: [*c]const wchar_t, size: Py_ssize_t) c_int;
pub extern fn PyUnicodeWriter_WriteUCS4(writer: ?*PyUnicodeWriter, str: [*c]Py_UCS4, size: Py_ssize_t) c_int;
pub extern fn PyUnicodeWriter_WriteStr(writer: ?*PyUnicodeWriter, obj: [*c]PyObject) c_int;
pub extern fn PyUnicodeWriter_WriteRepr(writer: ?*PyUnicodeWriter, obj: [*c]PyObject) c_int;
pub extern fn PyUnicodeWriter_WriteSubstring(writer: ?*PyUnicodeWriter, str: [*c]PyObject, start: Py_ssize_t, end: Py_ssize_t) c_int;
pub extern fn PyUnicodeWriter_Format(writer: ?*PyUnicodeWriter, format: [*c]const u8, ...) c_int;
pub extern fn PyUnicodeWriter_DecodeUTF8Stateful(writer: ?*PyUnicodeWriter, string: [*c]const u8, length: Py_ssize_t, errors: [*c]const u8, consumed: [*c]Py_ssize_t) c_int;
pub const _PyUnicodeWriter = extern struct {
    buffer: [*c]PyObject = null,
    data: ?*anyopaque = null,
    kind: c_int = 0,
    maxchar: Py_UCS4 = 0,
    size: Py_ssize_t = 0,
    pos: Py_ssize_t = 0,
    min_length: Py_ssize_t = 0,
    min_char: Py_UCS4 = 0,
    overallocate: u8 = 0,
    readonly: u8 = 0,
    pub const _PyUnicodeWriter_Init = __root._PyUnicodeWriter_Init;
    pub const _PyUnicodeWriter_PrepareInternal = __root._PyUnicodeWriter_PrepareInternal;
    pub const _PyUnicodeWriter_PrepareKindInternal = __root._PyUnicodeWriter_PrepareKindInternal;
    pub const _PyUnicodeWriter_WriteChar = __root._PyUnicodeWriter_WriteChar;
    pub const _PyUnicodeWriter_WriteStr = __root._PyUnicodeWriter_WriteStr;
    pub const _PyUnicodeWriter_WriteSubstring = __root._PyUnicodeWriter_WriteSubstring;
    pub const _PyUnicodeWriter_WriteASCIIString = __root._PyUnicodeWriter_WriteASCIIString;
    pub const _PyUnicodeWriter_WriteLatin1String = __root._PyUnicodeWriter_WriteLatin1String;
    pub const _PyUnicodeWriter_Finish = __root._PyUnicodeWriter_Finish;
    pub const _PyUnicodeWriter_Dealloc = __root._PyUnicodeWriter_Dealloc;
    pub const Init = __root._PyUnicodeWriter_Init;
    pub const PrepareInternal = __root._PyUnicodeWriter_PrepareInternal;
    pub const PrepareKindInternal = __root._PyUnicodeWriter_PrepareKindInternal;
    pub const WriteChar = __root._PyUnicodeWriter_WriteChar;
    pub const WriteStr = __root._PyUnicodeWriter_WriteStr;
    pub const WriteSubstring = __root._PyUnicodeWriter_WriteSubstring;
    pub const WriteASCIIString = __root._PyUnicodeWriter_WriteASCIIString;
    pub const WriteLatin1String = __root._PyUnicodeWriter_WriteLatin1String;
    pub const Finish = __root._PyUnicodeWriter_Finish;
    pub const Dealloc = __root._PyUnicodeWriter_Dealloc;
};
pub extern fn _PyUnicodeWriter_Init(writer: [*c]_PyUnicodeWriter) void;
pub extern fn _PyUnicodeWriter_PrepareInternal(writer: [*c]_PyUnicodeWriter, length: Py_ssize_t, maxchar: Py_UCS4) c_int;
pub extern fn _PyUnicodeWriter_PrepareKindInternal(writer: [*c]_PyUnicodeWriter, kind: c_int) c_int;
pub extern fn _PyUnicodeWriter_WriteChar(writer: [*c]_PyUnicodeWriter, ch: Py_UCS4) c_int;
pub extern fn _PyUnicodeWriter_WriteStr(writer: [*c]_PyUnicodeWriter, str: [*c]PyObject) c_int;
pub extern fn _PyUnicodeWriter_WriteSubstring(writer: [*c]_PyUnicodeWriter, str: [*c]PyObject, start: Py_ssize_t, end: Py_ssize_t) c_int;
pub extern fn _PyUnicodeWriter_WriteASCIIString(writer: [*c]_PyUnicodeWriter, str: [*c]const u8, len: Py_ssize_t) c_int;
pub extern fn _PyUnicodeWriter_WriteLatin1String(writer: [*c]_PyUnicodeWriter, str: [*c]const u8, len: Py_ssize_t) c_int;
pub extern fn _PyUnicodeWriter_Finish(writer: [*c]_PyUnicodeWriter) [*c]PyObject;
pub extern fn _PyUnicodeWriter_Dealloc(writer: [*c]_PyUnicodeWriter) void;
pub extern fn PyUnicode_AsUTF8(unicode: [*c]PyObject) [*c]const u8;
pub fn _PyUnicode_AsString(arg_unicode: [*c]PyObject) callconv(.c) [*c]const u8 {
    var unicode = arg_unicode;
    _ = &unicode;
    return PyUnicode_AsUTF8(unicode);
}
pub extern fn _PyUnicode_IsLowercase(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_IsUppercase(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_IsTitlecase(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_IsWhitespace(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_IsLinebreak(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_ToLowercase(ch: Py_UCS4) Py_UCS4;
pub extern fn _PyUnicode_ToUppercase(ch: Py_UCS4) Py_UCS4;
pub extern fn _PyUnicode_ToTitlecase(ch: Py_UCS4) Py_UCS4;
pub extern fn _PyUnicode_ToDecimalDigit(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_ToDigit(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_ToNumeric(ch: Py_UCS4) f64;
pub extern fn _PyUnicode_IsDecimalDigit(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_IsDigit(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_IsNumeric(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_IsPrintable(ch: Py_UCS4) c_int;
pub extern fn _PyUnicode_IsAlpha(ch: Py_UCS4) c_int;
pub const _Py_ascii_whitespace: [*c]const u8 = @extern([*c]const u8, .{
    .name = "_Py_ascii_whitespace",
});
pub fn Py_UNICODE_ISSPACE(arg_ch: Py_UCS4) callconv(.c) c_int {
    var ch = arg_ch;
    _ = &ch;
    if (ch < @as(Py_UCS4, 128)) {
        return _Py_ascii_whitespace[ch];
    }
    return _PyUnicode_IsWhitespace(ch);
}
pub fn Py_UNICODE_ISALNUM(arg_ch: Py_UCS4) callconv(.c) c_int {
    var ch = arg_ch;
    _ = &ch;
    return @intFromBool((((_PyUnicode_IsAlpha(ch) != 0) or (_PyUnicode_IsDecimalDigit(ch) != 0)) or (_PyUnicode_IsDigit(ch) != 0)) or (_PyUnicode_IsNumeric(ch) != 0));
}
pub extern fn _PyUnicode_FromId([*c]_Py_Identifier) [*c]PyObject;
pub extern fn PyErr_SetNone([*c]PyObject) void;
pub extern fn PyErr_SetObject([*c]PyObject, [*c]PyObject) void;
pub extern fn PyErr_SetString(exception: [*c]PyObject, string: [*c]const u8) void;
pub extern fn PyErr_Occurred() [*c]PyObject;
pub extern fn PyErr_Clear() void;
pub extern fn PyErr_Fetch([*c][*c]PyObject, [*c][*c]PyObject, [*c][*c]PyObject) void;
pub extern fn PyErr_Restore([*c]PyObject, [*c]PyObject, [*c]PyObject) void;
pub extern fn PyErr_GetRaisedException() [*c]PyObject;
pub extern fn PyErr_SetRaisedException([*c]PyObject) void;
pub extern fn PyErr_GetHandledException() [*c]PyObject;
pub extern fn PyErr_SetHandledException([*c]PyObject) void;
pub extern fn PyErr_GetExcInfo([*c][*c]PyObject, [*c][*c]PyObject, [*c][*c]PyObject) void;
pub extern fn PyErr_SetExcInfo([*c]PyObject, [*c]PyObject, [*c]PyObject) void;
pub extern fn Py_FatalError(message: [*c]const u8) noreturn;
pub extern fn PyErr_GivenExceptionMatches([*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyErr_ExceptionMatches([*c]PyObject) c_int;
pub extern fn PyErr_NormalizeException([*c][*c]PyObject, [*c][*c]PyObject, [*c][*c]PyObject) void;
pub extern fn PyException_SetTraceback([*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyException_GetTraceback([*c]PyObject) [*c]PyObject;
pub extern fn PyException_GetCause([*c]PyObject) [*c]PyObject;
pub extern fn PyException_SetCause([*c]PyObject, [*c]PyObject) void;
pub extern fn PyException_GetContext([*c]PyObject) [*c]PyObject;
pub extern fn PyException_SetContext([*c]PyObject, [*c]PyObject) void;
pub extern fn PyException_GetArgs([*c]PyObject) [*c]PyObject;
pub extern fn PyException_SetArgs([*c]PyObject, [*c]PyObject) void;
pub extern fn PyExceptionClass_Name([*c]PyObject) [*c]const u8;
pub extern var PyExc_BaseException: [*c]PyObject;
pub extern var PyExc_Exception: [*c]PyObject;
pub extern var PyExc_BaseExceptionGroup: [*c]PyObject;
pub extern var PyExc_StopAsyncIteration: [*c]PyObject;
pub extern var PyExc_StopIteration: [*c]PyObject;
pub extern var PyExc_GeneratorExit: [*c]PyObject;
pub extern var PyExc_ArithmeticError: [*c]PyObject;
pub extern var PyExc_LookupError: [*c]PyObject;
pub extern var PyExc_AssertionError: [*c]PyObject;
pub extern var PyExc_AttributeError: [*c]PyObject;
pub extern var PyExc_BufferError: [*c]PyObject;
pub extern var PyExc_EOFError: [*c]PyObject;
pub extern var PyExc_FloatingPointError: [*c]PyObject;
pub extern var PyExc_OSError: [*c]PyObject;
pub extern var PyExc_ImportError: [*c]PyObject;
pub extern var PyExc_ModuleNotFoundError: [*c]PyObject;
pub extern var PyExc_IndexError: [*c]PyObject;
pub extern var PyExc_KeyError: [*c]PyObject;
pub extern var PyExc_KeyboardInterrupt: [*c]PyObject;
pub extern var PyExc_MemoryError: [*c]PyObject;
pub extern var PyExc_NameError: [*c]PyObject;
pub extern var PyExc_OverflowError: [*c]PyObject;
pub extern var PyExc_RuntimeError: [*c]PyObject;
pub extern var PyExc_RecursionError: [*c]PyObject;
pub extern var PyExc_NotImplementedError: [*c]PyObject;
pub extern var PyExc_SyntaxError: [*c]PyObject;
pub extern var PyExc_IndentationError: [*c]PyObject;
pub extern var PyExc_TabError: [*c]PyObject;
pub extern var PyExc_ReferenceError: [*c]PyObject;
pub extern var PyExc_SystemError: [*c]PyObject;
pub extern var PyExc_SystemExit: [*c]PyObject;
pub extern var PyExc_TypeError: [*c]PyObject;
pub extern var PyExc_UnboundLocalError: [*c]PyObject;
pub extern var PyExc_UnicodeError: [*c]PyObject;
pub extern var PyExc_UnicodeEncodeError: [*c]PyObject;
pub extern var PyExc_UnicodeDecodeError: [*c]PyObject;
pub extern var PyExc_UnicodeTranslateError: [*c]PyObject;
pub extern var PyExc_ValueError: [*c]PyObject;
pub extern var PyExc_ZeroDivisionError: [*c]PyObject;
pub extern var PyExc_BlockingIOError: [*c]PyObject;
pub extern var PyExc_BrokenPipeError: [*c]PyObject;
pub extern var PyExc_ChildProcessError: [*c]PyObject;
pub extern var PyExc_ConnectionError: [*c]PyObject;
pub extern var PyExc_ConnectionAbortedError: [*c]PyObject;
pub extern var PyExc_ConnectionRefusedError: [*c]PyObject;
pub extern var PyExc_ConnectionResetError: [*c]PyObject;
pub extern var PyExc_FileExistsError: [*c]PyObject;
pub extern var PyExc_FileNotFoundError: [*c]PyObject;
pub extern var PyExc_InterruptedError: [*c]PyObject;
pub extern var PyExc_IsADirectoryError: [*c]PyObject;
pub extern var PyExc_NotADirectoryError: [*c]PyObject;
pub extern var PyExc_PermissionError: [*c]PyObject;
pub extern var PyExc_ProcessLookupError: [*c]PyObject;
pub extern var PyExc_TimeoutError: [*c]PyObject;
pub extern var PyExc_EnvironmentError: [*c]PyObject;
pub extern var PyExc_IOError: [*c]PyObject;
pub extern var PyExc_Warning: [*c]PyObject;
pub extern var PyExc_UserWarning: [*c]PyObject;
pub extern var PyExc_DeprecationWarning: [*c]PyObject;
pub extern var PyExc_PendingDeprecationWarning: [*c]PyObject;
pub extern var PyExc_SyntaxWarning: [*c]PyObject;
pub extern var PyExc_RuntimeWarning: [*c]PyObject;
pub extern var PyExc_FutureWarning: [*c]PyObject;
pub extern var PyExc_ImportWarning: [*c]PyObject;
pub extern var PyExc_UnicodeWarning: [*c]PyObject;
pub extern var PyExc_BytesWarning: [*c]PyObject;
pub extern var PyExc_EncodingWarning: [*c]PyObject;
pub extern var PyExc_ResourceWarning: [*c]PyObject;
pub extern fn PyErr_BadArgument() c_int;
pub extern fn PyErr_NoMemory() [*c]PyObject;
pub extern fn PyErr_SetFromErrno([*c]PyObject) [*c]PyObject;
pub extern fn PyErr_SetFromErrnoWithFilenameObject([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyErr_SetFromErrnoWithFilenameObjects([*c]PyObject, [*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyErr_SetFromErrnoWithFilename(exc: [*c]PyObject, filename: [*c]const u8) [*c]PyObject;
pub extern fn PyErr_Format(exception: [*c]PyObject, format: [*c]const u8, ...) [*c]PyObject;
pub extern fn PyErr_FormatV(exception: [*c]PyObject, format: [*c]const u8, vargs: [*c]struct___va_list_tag_3) [*c]PyObject;
pub extern fn PyErr_SetImportErrorSubclass([*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyErr_SetImportError([*c]PyObject, [*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyErr_BadInternalCall() void;
pub extern fn _PyErr_BadInternalCall(filename: [*c]const u8, lineno: c_int) void;
pub extern fn PyErr_NewException(name: [*c]const u8, base: [*c]PyObject, dict: [*c]PyObject) [*c]PyObject;
pub extern fn PyErr_NewExceptionWithDoc(name: [*c]const u8, doc: [*c]const u8, base: [*c]PyObject, dict: [*c]PyObject) [*c]PyObject;
pub extern fn PyErr_WriteUnraisable([*c]PyObject) void;
pub extern fn PyErr_CheckSignals() c_int;
pub extern fn PyErr_SetInterrupt() void;
pub extern fn PyErr_SetInterruptEx(signum: c_int) c_int;
pub extern fn PyErr_SyntaxLocation(filename: [*c]const u8, lineno: c_int) void;
pub extern fn PyErr_SyntaxLocationEx(filename: [*c]const u8, lineno: c_int, col_offset: c_int) void;
pub extern fn PyErr_ProgramText(filename: [*c]const u8, lineno: c_int) [*c]PyObject;
pub extern fn PyUnicodeDecodeError_Create(encoding: [*c]const u8, object: [*c]const u8, length: Py_ssize_t, start: Py_ssize_t, end: Py_ssize_t, reason: [*c]const u8) [*c]PyObject;
pub extern fn PyUnicodeEncodeError_GetEncoding([*c]PyObject) [*c]PyObject;
pub extern fn PyUnicodeDecodeError_GetEncoding([*c]PyObject) [*c]PyObject;
pub extern fn PyUnicodeEncodeError_GetObject([*c]PyObject) [*c]PyObject;
pub extern fn PyUnicodeDecodeError_GetObject([*c]PyObject) [*c]PyObject;
pub extern fn PyUnicodeTranslateError_GetObject([*c]PyObject) [*c]PyObject;
pub extern fn PyUnicodeEncodeError_GetStart([*c]PyObject, [*c]Py_ssize_t) c_int;
pub extern fn PyUnicodeDecodeError_GetStart([*c]PyObject, [*c]Py_ssize_t) c_int;
pub extern fn PyUnicodeTranslateError_GetStart([*c]PyObject, [*c]Py_ssize_t) c_int;
pub extern fn PyUnicodeEncodeError_SetStart([*c]PyObject, Py_ssize_t) c_int;
pub extern fn PyUnicodeDecodeError_SetStart([*c]PyObject, Py_ssize_t) c_int;
pub extern fn PyUnicodeTranslateError_SetStart([*c]PyObject, Py_ssize_t) c_int;
pub extern fn PyUnicodeEncodeError_GetEnd([*c]PyObject, [*c]Py_ssize_t) c_int;
pub extern fn PyUnicodeDecodeError_GetEnd([*c]PyObject, [*c]Py_ssize_t) c_int;
pub extern fn PyUnicodeTranslateError_GetEnd([*c]PyObject, [*c]Py_ssize_t) c_int;
pub extern fn PyUnicodeEncodeError_SetEnd([*c]PyObject, Py_ssize_t) c_int;
pub extern fn PyUnicodeDecodeError_SetEnd([*c]PyObject, Py_ssize_t) c_int;
pub extern fn PyUnicodeTranslateError_SetEnd([*c]PyObject, Py_ssize_t) c_int;
pub extern fn PyUnicodeEncodeError_GetReason([*c]PyObject) [*c]PyObject;
pub extern fn PyUnicodeDecodeError_GetReason([*c]PyObject) [*c]PyObject;
pub extern fn PyUnicodeTranslateError_GetReason([*c]PyObject) [*c]PyObject;
pub extern fn PyUnicodeEncodeError_SetReason(exc: [*c]PyObject, reason: [*c]const u8) c_int;
pub extern fn PyUnicodeDecodeError_SetReason(exc: [*c]PyObject, reason: [*c]const u8) c_int;
pub extern fn PyUnicodeTranslateError_SetReason(exc: [*c]PyObject, reason: [*c]const u8) c_int;
pub extern fn PyOS_snprintf(str: [*c]u8, size: usize, format: [*c]const u8, ...) c_int;
pub extern fn PyOS_vsnprintf(str: [*c]u8, size: usize, format: [*c]const u8, va: [*c]struct___va_list_tag_3) c_int;
pub const PyBaseExceptionObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
};
pub const PyBaseExceptionGroupObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    msg: [*c]PyObject = null,
    excs: [*c]PyObject = null,
};
pub const PySyntaxErrorObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    msg: [*c]PyObject = null,
    filename: [*c]PyObject = null,
    lineno: [*c]PyObject = null,
    offset: [*c]PyObject = null,
    end_lineno: [*c]PyObject = null,
    end_offset: [*c]PyObject = null,
    text: [*c]PyObject = null,
    print_file_and_line: [*c]PyObject = null,
    metadata: [*c]PyObject = null,
};
pub const PyImportErrorObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    msg: [*c]PyObject = null,
    name: [*c]PyObject = null,
    path: [*c]PyObject = null,
    name_from: [*c]PyObject = null,
};
pub const PyUnicodeErrorObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    encoding: [*c]PyObject = null,
    object: [*c]PyObject = null,
    start: Py_ssize_t = 0,
    end: Py_ssize_t = 0,
    reason: [*c]PyObject = null,
};
pub const PySystemExitObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    code: [*c]PyObject = null,
};
pub const PyOSErrorObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    myerrno: [*c]PyObject = null,
    strerror: [*c]PyObject = null,
    filename: [*c]PyObject = null,
    filename2: [*c]PyObject = null,
    written: Py_ssize_t = 0,
};
pub const PyStopIterationObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    value: [*c]PyObject = null,
};
pub const PyNameErrorObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    name: [*c]PyObject = null,
};
pub const PyAttributeErrorObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    dict: [*c]PyObject = null,
    args: [*c]PyObject = null,
    notes: [*c]PyObject = null,
    traceback: [*c]PyObject = null,
    context: [*c]PyObject = null,
    cause: [*c]PyObject = null,
    suppress_context: u8 = 0,
    obj: [*c]PyObject = null,
    name: [*c]PyObject = null,
};
pub const PyEnvironmentErrorObject = PyOSErrorObject;
pub extern fn _PyErr_ChainExceptions1([*c]PyObject) void;
pub extern fn PyUnstable_Exc_PrepReraiseStar(orig: [*c]PyObject, excs: [*c]PyObject) [*c]PyObject;
pub extern fn PySignal_SetWakeupFd(fd: c_int) c_int;
pub extern fn PyErr_SyntaxLocationObject(filename: [*c]PyObject, lineno: c_int, col_offset: c_int) void;
pub extern fn PyErr_RangedSyntaxLocationObject(filename: [*c]PyObject, lineno: c_int, col_offset: c_int, end_lineno: c_int, end_col_offset: c_int) void;
pub extern fn PyErr_ProgramTextObject(filename: [*c]PyObject, lineno: c_int) [*c]PyObject;
pub extern fn _Py_FatalErrorFunc(func: [*c]const u8, message: [*c]const u8) noreturn;
pub extern fn PyErr_FormatUnraisable([*c]const u8, ...) void;
pub extern var PyExc_PythonFinalizationError: [*c]PyObject;
pub extern fn PyLong_FromLong(c_long) [*c]PyObject;
pub extern fn PyLong_FromUnsignedLong(c_ulong) [*c]PyObject;
pub extern fn PyLong_FromSize_t(usize) [*c]PyObject;
pub extern fn PyLong_FromSsize_t(Py_ssize_t) [*c]PyObject;
pub extern fn PyLong_FromDouble(f64) [*c]PyObject;
pub extern fn PyLong_AsLong([*c]PyObject) c_long;
pub extern fn PyLong_AsLongAndOverflow([*c]PyObject, [*c]c_int) c_long;
pub extern fn PyLong_AsSsize_t([*c]PyObject) Py_ssize_t;
pub extern fn PyLong_AsSize_t([*c]PyObject) usize;
pub extern fn PyLong_AsUnsignedLong([*c]PyObject) c_ulong;
pub extern fn PyLong_AsUnsignedLongMask([*c]PyObject) c_ulong;
pub extern fn PyLong_AsInt([*c]PyObject) c_int;
pub extern fn PyLong_FromInt32(value: i32) [*c]PyObject;
pub extern fn PyLong_FromUInt32(value: u32) [*c]PyObject;
pub extern fn PyLong_FromInt64(value: i64) [*c]PyObject;
pub extern fn PyLong_FromUInt64(value: u64) [*c]PyObject;
pub extern fn PyLong_AsInt32(obj: [*c]PyObject, value: [*c]i32) c_int;
pub extern fn PyLong_AsUInt32(obj: [*c]PyObject, value: [*c]u32) c_int;
pub extern fn PyLong_AsInt64(obj: [*c]PyObject, value: [*c]i64) c_int;
pub extern fn PyLong_AsUInt64(obj: [*c]PyObject, value: [*c]u64) c_int;
pub extern fn PyLong_AsNativeBytes(v: [*c]PyObject, buffer: ?*anyopaque, n_bytes: Py_ssize_t, flags: c_int) Py_ssize_t;
pub extern fn PyLong_FromNativeBytes(buffer: ?*const anyopaque, n_bytes: usize, flags: c_int) [*c]PyObject;
pub extern fn PyLong_FromUnsignedNativeBytes(buffer: ?*const anyopaque, n_bytes: usize, flags: c_int) [*c]PyObject;
pub extern fn PyLong_GetInfo() [*c]PyObject;
pub extern fn PyLong_AsDouble([*c]PyObject) f64;
pub extern fn PyLong_FromVoidPtr(?*anyopaque) [*c]PyObject;
pub extern fn PyLong_AsVoidPtr([*c]PyObject) ?*anyopaque;
pub extern fn PyLong_FromLongLong(c_longlong) [*c]PyObject;
pub extern fn PyLong_FromUnsignedLongLong(c_ulonglong) [*c]PyObject;
pub extern fn PyLong_AsLongLong([*c]PyObject) c_longlong;
pub extern fn PyLong_AsUnsignedLongLong([*c]PyObject) c_ulonglong;
pub extern fn PyLong_AsUnsignedLongLongMask([*c]PyObject) c_ulonglong;
pub extern fn PyLong_AsLongLongAndOverflow([*c]PyObject, [*c]c_int) c_longlong;
pub extern fn PyLong_FromString([*c]const u8, [*c][*c]u8, c_int) [*c]PyObject;
pub extern fn PyOS_strtoul([*c]const u8, [*c][*c]u8, c_int) c_ulong;
pub extern fn PyOS_strtol([*c]const u8, [*c][*c]u8, c_int) c_long;
pub extern fn PyLong_FromUnicodeObject(u: [*c]PyObject, base: c_int) [*c]PyObject;
pub extern fn PyUnstable_Long_IsCompact(op: [*c]const PyLongObject) c_int;
pub extern fn PyUnstable_Long_CompactValue(op: [*c]const PyLongObject) Py_ssize_t;
pub extern fn PyLong_IsPositive(obj: [*c]PyObject) c_int;
pub extern fn PyLong_IsNegative(obj: [*c]PyObject) c_int;
pub extern fn PyLong_IsZero(obj: [*c]PyObject) c_int;
pub extern fn PyLong_GetSign(v: [*c]PyObject, sign: [*c]c_int) c_int;
pub extern fn _PyLong_Sign(v: [*c]PyObject) c_int;
pub extern fn _PyLong_NumBits(v: [*c]PyObject) i64;
pub extern fn _PyLong_FromByteArray(bytes: [*c]const u8, n: usize, little_endian: c_int, is_signed: c_int) [*c]PyObject;
pub extern fn _PyLong_AsByteArray(v: [*c]PyLongObject, bytes: [*c]u8, n: usize, little_endian: c_int, is_signed: c_int, with_exceptions: c_int) c_int;
pub extern fn _PyLong_GCD([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub const sdigit = i32;
pub const twodigits = u64;
pub const stwodigits = i64;
pub extern fn _PyLong_New(Py_ssize_t) [*c]PyLongObject;
pub extern fn _PyLong_Copy(src: [*c]PyLongObject) [*c]PyObject;
pub extern fn _PyLong_FromDigits(negative: c_int, digit_count: Py_ssize_t, digits: [*c]digit) [*c]PyLongObject;
pub fn _PyLong_IsCompact(arg_op: [*c]const PyLongObject) callconv(.c) c_int {
    var op = arg_op;
    _ = &op;
    _ = @as(c_int, 0);
    return @intFromBool(op.*.long_value.lv_tag < @as(usize, @bitCast(@as(c_long, @as(c_int, 2) << @intCast(_PyLong_NON_SIZE_BITS)))));
}
pub fn _PyLong_CompactValue(arg_op: [*c]const PyLongObject) callconv(.c) Py_ssize_t {
    var op = arg_op;
    _ = &op;
    var sign: Py_ssize_t = undefined;
    _ = &sign;
    _ = @as(c_int, 0);
    _ = @as(c_int, 0);
    sign = @bitCast(@as(c_ulong, @truncate(@as(usize, 1) -% (op.*.long_value.lv_tag & @as(usize, _PyLong_SIGN_MASK)))));
    return sign * @as(Py_ssize_t, op.*.long_value.ob_digit[@as(c_int, 0)]);
}
pub const struct_PyLongLayout = extern struct {
    bits_per_digit: u8 = 0,
    digit_size: u8 = 0,
    digits_order: i8 = 0,
    digit_endianness: i8 = 0,
};
pub const PyLongLayout = struct_PyLongLayout;
pub extern fn PyLong_GetNativeLayout() [*c]const PyLongLayout;
pub const struct_PyLongExport = extern struct {
    value: i64 = 0,
    negative: u8 = 0,
    ndigits: Py_ssize_t = 0,
    digits: ?*const anyopaque = null,
    _reserved: Py_uintptr_t = 0,
    pub const PyLong_FreeExport = __root.PyLong_FreeExport;
    pub const FreeExport = __root.PyLong_FreeExport;
};
pub const PyLongExport = struct_PyLongExport;
pub extern fn PyLong_Export(obj: [*c]PyObject, export_long: [*c]PyLongExport) c_int;
pub extern fn PyLong_FreeExport(export_long: [*c]PyLongExport) void;
pub const struct_PyLongWriter = opaque {
    pub const PyLongWriter_Finish = __root.PyLongWriter_Finish;
    pub const PyLongWriter_Discard = __root.PyLongWriter_Discard;
    pub const Finish = __root.PyLongWriter_Finish;
    pub const Discard = __root.PyLongWriter_Discard;
};
pub const PyLongWriter = struct_PyLongWriter;
pub extern fn PyLongWriter_Create(negative: c_int, ndigits: Py_ssize_t, digits: [*c]?*anyopaque) ?*PyLongWriter;
pub extern fn PyLongWriter_Finish(writer: ?*PyLongWriter) [*c]PyObject;
pub extern fn PyLongWriter_Discard(writer: ?*PyLongWriter) void;
pub extern var _Py_FalseStruct: PyLongObject;
pub extern var _Py_TrueStruct: PyLongObject;
pub extern fn Py_IsTrue(x: [*c]PyObject) c_int;
pub extern fn Py_IsFalse(x: [*c]PyObject) c_int;
pub extern fn PyBool_FromLong(c_long) [*c]PyObject;
pub extern var PyFloat_Type: PyTypeObject;
pub extern fn PyFloat_GetMax() f64;
pub extern fn PyFloat_GetMin() f64;
pub extern fn PyFloat_GetInfo() [*c]PyObject;
pub extern fn PyFloat_FromString([*c]PyObject) [*c]PyObject;
pub extern fn PyFloat_FromDouble(f64) [*c]PyObject;
pub extern fn PyFloat_AsDouble([*c]PyObject) f64;
pub const PyFloatObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    ob_fval: f64 = 0,
};
pub fn PyFloat_AS_DOUBLE(arg_op: [*c]PyObject) callconv(.c) f64 {
    var op = arg_op;
    _ = &op;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyFloatObject, @ptrCast(@alignCast(op)));
    }).*.ob_fval;
}
pub extern fn PyFloat_Pack2(x: f64, p: [*c]u8, le: c_int) c_int;
pub extern fn PyFloat_Pack4(x: f64, p: [*c]u8, le: c_int) c_int;
pub extern fn PyFloat_Pack8(x: f64, p: [*c]u8, le: c_int) c_int;
pub extern fn PyFloat_Unpack2(p: [*c]const u8, le: c_int) f64;
pub extern fn PyFloat_Unpack4(p: [*c]const u8, le: c_int) f64;
pub extern fn PyFloat_Unpack8(p: [*c]const u8, le: c_int) f64;
pub extern var PyComplex_Type: PyTypeObject;
pub extern fn PyComplex_FromDoubles(real: f64, imag: f64) [*c]PyObject;
pub extern fn PyComplex_RealAsDouble(op: [*c]PyObject) f64;
pub extern fn PyComplex_ImagAsDouble(op: [*c]PyObject) f64;
pub const Py_complex = extern struct {
    real: f64 = 0,
    imag: f64 = 0,
    pub const _Py_c_sum = __root._Py_c_sum;
    pub const _Py_c_diff = __root._Py_c_diff;
    pub const _Py_c_neg = __root._Py_c_neg;
    pub const _Py_c_prod = __root._Py_c_prod;
    pub const _Py_c_quot = __root._Py_c_quot;
    pub const _Py_c_pow = __root._Py_c_pow;
    pub const _Py_c_abs = __root._Py_c_abs;
    pub const PyComplex_FromCComplex = __root.PyComplex_FromCComplex;
    pub const sum = __root._Py_c_sum;
    pub const diff = __root._Py_c_diff;
    pub const neg = __root._Py_c_neg;
    pub const prod = __root._Py_c_prod;
    pub const quot = __root._Py_c_quot;
    pub const FromCComplex = __root.PyComplex_FromCComplex;
};
pub extern fn _Py_c_sum(Py_complex, Py_complex) Py_complex;
pub extern fn _Py_c_diff(Py_complex, Py_complex) Py_complex;
pub extern fn _Py_c_neg(Py_complex) Py_complex;
pub extern fn _Py_c_prod(Py_complex, Py_complex) Py_complex;
pub extern fn _Py_c_quot(Py_complex, Py_complex) Py_complex;
pub extern fn _Py_c_pow(Py_complex, Py_complex) Py_complex;
pub extern fn _Py_c_abs(Py_complex) f64;
pub const PyComplexObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    cval: Py_complex = @import("std").mem.zeroes(Py_complex),
};
pub extern fn PyComplex_FromCComplex(Py_complex) [*c]PyObject;
pub extern fn PyComplex_AsCComplex(op: [*c]PyObject) Py_complex;
pub extern var PyRange_Type: PyTypeObject;
pub extern var PyRangeIter_Type: PyTypeObject;
pub extern var PyLongRangeIter_Type: PyTypeObject;
pub extern var PyMemoryView_Type: PyTypeObject;
pub extern fn PyMemoryView_FromObject(base: [*c]PyObject) [*c]PyObject;
pub extern fn PyMemoryView_FromMemory(mem: [*c]u8, size: Py_ssize_t, flags: c_int) [*c]PyObject;
pub extern fn PyMemoryView_FromBuffer(info: [*c]const Py_buffer) [*c]PyObject;
pub extern fn PyMemoryView_GetContiguous(base: [*c]PyObject, buffertype: c_int, order: u8) [*c]PyObject;
pub const _PyManagedBufferObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    flags: c_int = 0,
    exports: Py_ssize_t = 0,
    master: Py_buffer = @import("std").mem.zeroes(Py_buffer),
};
pub const PyMemoryViewObject = extern struct {
    ob_base: PyVarObject = @import("std").mem.zeroes(PyVarObject),
    mbuf: [*c]_PyManagedBufferObject = null,
    hash: Py_hash_t = 0,
    flags: c_int = 0,
    exports: Py_ssize_t = 0,
    view: Py_buffer = @import("std").mem.zeroes(Py_buffer),
    weakreflist: [*c]PyObject = null,
    ob_array: [1]Py_ssize_t = @import("std").mem.zeroes([1]Py_ssize_t),
};
pub fn PyMemoryView_GET_BUFFER(arg_op: [*c]PyObject) callconv(.c) [*c]Py_buffer {
    var op = arg_op;
    _ = &op;
    return &@as([*c]PyMemoryViewObject, @ptrCast(@alignCast(op))).*.view;
}
pub fn PyMemoryView_GET_BASE(arg_op: [*c]PyObject) callconv(.c) [*c]PyObject {
    var op = arg_op;
    _ = &op;
    return @as([*c]PyMemoryViewObject, @ptrCast(@alignCast(op))).*.view.obj;
}
pub extern var PyTuple_Type: PyTypeObject;
pub extern var PyTupleIter_Type: PyTypeObject;
pub extern fn PyTuple_New(size: Py_ssize_t) [*c]PyObject;
pub extern fn PyTuple_Size([*c]PyObject) Py_ssize_t;
pub extern fn PyTuple_GetItem([*c]PyObject, Py_ssize_t) [*c]PyObject;
pub extern fn PyTuple_SetItem([*c]PyObject, Py_ssize_t, [*c]PyObject) c_int;
pub extern fn PyTuple_GetSlice([*c]PyObject, Py_ssize_t, Py_ssize_t) [*c]PyObject;
pub extern fn PyTuple_Pack(Py_ssize_t, ...) [*c]PyObject;
pub const PyTupleObject = extern struct {
    ob_base: PyVarObject = @import("std").mem.zeroes(PyVarObject),
    ob_hash: Py_hash_t = 0,
    ob_item: [1][*c]PyObject = @import("std").mem.zeroes([1][*c]PyObject),
};
pub extern fn _PyTuple_Resize([*c][*c]PyObject, Py_ssize_t) c_int;
pub fn PyTuple_GET_SIZE(arg_op: [*c]PyObject) callconv(.c) Py_ssize_t {
    var op = arg_op;
    _ = &op;
    var tuple: [*c]PyTupleObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyTupleObject, @ptrCast(@alignCast(op)));
    };
    _ = &tuple;
    return Py_SIZE(@as([*c]PyObject, @ptrCast(@alignCast(tuple))));
}
pub fn PyTuple_SET_ITEM(arg_op: [*c]PyObject, arg_index_1: Py_ssize_t, arg_value: [*c]PyObject) callconv(.c) void {
    var op = arg_op;
    _ = &op;
    var index_1 = arg_index_1;
    _ = &index_1;
    var value = arg_value;
    _ = &value;
    var tuple: [*c]PyTupleObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyTupleObject, @ptrCast(@alignCast(op)));
    };
    _ = &tuple;
    _ = @as(c_int, 0);
    _ = @as(c_int, 0);
    tuple.*.ob_item[@bitCast(@as(isize, @intCast(index_1)))] = value;
}
pub extern var PyList_Type: PyTypeObject;
pub extern var PyListIter_Type: PyTypeObject;
pub extern var PyListRevIter_Type: PyTypeObject;
pub extern fn PyList_New(size: Py_ssize_t) [*c]PyObject;
pub extern fn PyList_Size([*c]PyObject) Py_ssize_t;
pub extern fn PyList_GetItem([*c]PyObject, Py_ssize_t) [*c]PyObject;
pub extern fn PyList_GetItemRef([*c]PyObject, Py_ssize_t) [*c]PyObject;
pub extern fn PyList_SetItem([*c]PyObject, Py_ssize_t, [*c]PyObject) c_int;
pub extern fn PyList_Insert([*c]PyObject, Py_ssize_t, [*c]PyObject) c_int;
pub extern fn PyList_Append([*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyList_GetSlice([*c]PyObject, Py_ssize_t, Py_ssize_t) [*c]PyObject;
pub extern fn PyList_SetSlice([*c]PyObject, Py_ssize_t, Py_ssize_t, [*c]PyObject) c_int;
pub extern fn PyList_Sort([*c]PyObject) c_int;
pub extern fn PyList_Reverse([*c]PyObject) c_int;
pub extern fn PyList_AsTuple([*c]PyObject) [*c]PyObject;
pub const PyListObject = extern struct {
    ob_base: PyVarObject = @import("std").mem.zeroes(PyVarObject),
    ob_item: [*c][*c]PyObject = null,
    allocated: Py_ssize_t = 0,
};
pub fn PyList_GET_SIZE(arg_op: [*c]PyObject) callconv(.c) Py_ssize_t {
    var op = arg_op;
    _ = &op;
    var list: [*c]PyListObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyListObject, @ptrCast(@alignCast(op)));
    };
    _ = &list;
    return Py_SIZE(@as([*c]PyObject, @ptrCast(@alignCast(list))));
}
pub fn PyList_SET_ITEM(arg_op: [*c]PyObject, arg_index_1: Py_ssize_t, arg_value: [*c]PyObject) callconv(.c) void {
    var op = arg_op;
    _ = &op;
    var index_1 = arg_index_1;
    _ = &index_1;
    var value = arg_value;
    _ = &value;
    var list: [*c]PyListObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyListObject, @ptrCast(@alignCast(op)));
    };
    _ = &list;
    _ = @as(c_int, 0);
    _ = @as(c_int, 0);
    list.*.ob_item[@bitCast(@as(isize, @intCast(index_1)))] = value;
}
pub extern fn PyList_Extend(self: [*c]PyObject, iterable: [*c]PyObject) c_int;
pub extern fn PyList_Clear(self: [*c]PyObject) c_int;
pub extern var PyDict_Type: PyTypeObject;
pub extern fn PyDict_New() [*c]PyObject;
pub extern fn PyDict_GetItem(mp: [*c]PyObject, key: [*c]PyObject) [*c]PyObject;
pub extern fn PyDict_GetItemWithError(mp: [*c]PyObject, key: [*c]PyObject) [*c]PyObject;
pub extern fn PyDict_SetItem(mp: [*c]PyObject, key: [*c]PyObject, item: [*c]PyObject) c_int;
pub extern fn PyDict_DelItem(mp: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern fn PyDict_Clear(mp: [*c]PyObject) void;
pub extern fn PyDict_Next(mp: [*c]PyObject, pos: [*c]Py_ssize_t, key: [*c][*c]PyObject, value: [*c][*c]PyObject) c_int;
pub extern fn PyDict_Keys(mp: [*c]PyObject) [*c]PyObject;
pub extern fn PyDict_Values(mp: [*c]PyObject) [*c]PyObject;
pub extern fn PyDict_Items(mp: [*c]PyObject) [*c]PyObject;
pub extern fn PyDict_Size(mp: [*c]PyObject) Py_ssize_t;
pub extern fn PyDict_Copy(mp: [*c]PyObject) [*c]PyObject;
pub extern fn PyDict_Contains(mp: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern fn PyDict_Update(mp: [*c]PyObject, other: [*c]PyObject) c_int;
pub extern fn PyDict_Merge(mp: [*c]PyObject, other: [*c]PyObject, override: c_int) c_int;
pub extern fn PyDict_MergeFromSeq2(d: [*c]PyObject, seq2: [*c]PyObject, override: c_int) c_int;
pub extern fn PyDict_GetItemString(dp: [*c]PyObject, key: [*c]const u8) [*c]PyObject;
pub extern fn PyDict_SetItemString(dp: [*c]PyObject, key: [*c]const u8, item: [*c]PyObject) c_int;
pub extern fn PyDict_DelItemString(dp: [*c]PyObject, key: [*c]const u8) c_int;
pub extern fn PyDict_GetItemRef(mp: [*c]PyObject, key: [*c]PyObject, result: [*c][*c]PyObject) c_int;
pub extern fn PyDict_GetItemStringRef(mp: [*c]PyObject, key: [*c]const u8, result: [*c][*c]PyObject) c_int;
pub extern fn PyObject_GenericGetDict([*c]PyObject, ?*anyopaque) [*c]PyObject;
pub extern var PyDictKeys_Type: PyTypeObject;
pub extern var PyDictValues_Type: PyTypeObject;
pub extern var PyDictItems_Type: PyTypeObject;
pub extern var PyDictIterKey_Type: PyTypeObject;
pub extern var PyDictIterValue_Type: PyTypeObject;
pub extern var PyDictIterItem_Type: PyTypeObject;
pub extern var PyDictRevIterKey_Type: PyTypeObject;
pub extern var PyDictRevIterItem_Type: PyTypeObject;
pub extern var PyDictRevIterValue_Type: PyTypeObject;
pub const PyDictKeysObject = struct__dictkeysobject_16;
pub const struct__dictvalues = opaque {};
pub const PyDictValues = struct__dictvalues;
pub const PyDictObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    ma_used: Py_ssize_t = 0,
    _ma_watcher_tag: u64 = 0,
    ma_keys: ?*PyDictKeysObject = null,
    ma_values: ?*PyDictValues = null,
};
pub extern fn _PyDict_GetItem_KnownHash(mp: [*c]PyObject, key: [*c]PyObject, hash: Py_hash_t) [*c]PyObject;
pub extern fn _PyDict_GetItemStringWithError([*c]PyObject, [*c]const u8) [*c]PyObject;
pub extern fn PyDict_SetDefault(mp: [*c]PyObject, key: [*c]PyObject, defaultobj: [*c]PyObject) [*c]PyObject;
pub extern fn PyDict_SetDefaultRef(mp: [*c]PyObject, key: [*c]PyObject, default_value: [*c]PyObject, result: [*c][*c]PyObject) c_int;
pub fn PyDict_GET_SIZE(arg_op: [*c]PyObject) callconv(.c) Py_ssize_t {
    var op = arg_op;
    _ = &op;
    var mp: [*c]PyDictObject = undefined;
    _ = &mp;
    _ = @as(c_int, 0);
    mp = @as([*c]PyDictObject, @ptrCast(@alignCast(op)));
    return mp.*.ma_used;
}
pub extern fn PyDict_ContainsString(mp: [*c]PyObject, key: [*c]const u8) c_int;
pub extern fn _PyDict_NewPresized(minused: Py_ssize_t) [*c]PyObject;
pub extern fn PyDict_Pop(dict: [*c]PyObject, key: [*c]PyObject, result: [*c][*c]PyObject) c_int;
pub extern fn PyDict_PopString(dict: [*c]PyObject, key: [*c]const u8, result: [*c][*c]PyObject) c_int;
pub extern fn _PyDict_Pop(dict: [*c]PyObject, key: [*c]PyObject, default_value: [*c]PyObject) [*c]PyObject;
pub const PyDict_EVENT_ADDED: c_int = 0;
pub const PyDict_EVENT_MODIFIED: c_int = 1;
pub const PyDict_EVENT_DELETED: c_int = 2;
pub const PyDict_EVENT_CLONED: c_int = 3;
pub const PyDict_EVENT_CLEARED: c_int = 4;
pub const PyDict_EVENT_DEALLOCATED: c_int = 5;
pub const PyDict_WatchEvent = c_uint;
pub const PyDict_WatchCallback = ?*const fn (event: PyDict_WatchEvent, dict: [*c]PyObject, key: [*c]PyObject, new_value: [*c]PyObject) callconv(.c) c_int;
pub extern fn PyDict_AddWatcher(callback: PyDict_WatchCallback) c_int;
pub extern fn PyDict_ClearWatcher(watcher_id: c_int) c_int;
pub extern fn PyDict_Watch(watcher_id: c_int, dict: [*c]PyObject) c_int;
pub extern fn PyDict_Unwatch(watcher_id: c_int, dict: [*c]PyObject) c_int;
pub const struct__odictobject = opaque {};
pub const PyODictObject = struct__odictobject;
pub extern var PyODict_Type: PyTypeObject;
pub extern var PyODictIter_Type: PyTypeObject;
pub extern var PyODictKeys_Type: PyTypeObject;
pub extern var PyODictItems_Type: PyTypeObject;
pub extern var PyODictValues_Type: PyTypeObject;
pub extern fn PyODict_New() [*c]PyObject;
pub extern fn PyODict_SetItem(od: [*c]PyObject, key: [*c]PyObject, item: [*c]PyObject) c_int;
pub extern fn PyODict_DelItem(od: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern var PyEnum_Type: PyTypeObject;
pub extern var PyReversed_Type: PyTypeObject;
pub extern var PySet_Type: PyTypeObject;
pub extern var PyFrozenSet_Type: PyTypeObject;
pub extern var PySetIter_Type: PyTypeObject;
pub extern fn PySet_New([*c]PyObject) [*c]PyObject;
pub extern fn PyFrozenSet_New([*c]PyObject) [*c]PyObject;
pub extern fn PySet_Add(set: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern fn PySet_Clear(set: [*c]PyObject) c_int;
pub extern fn PySet_Contains(anyset: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern fn PySet_Discard(set: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern fn PySet_Pop(set: [*c]PyObject) [*c]PyObject;
pub extern fn PySet_Size(anyset: [*c]PyObject) Py_ssize_t;
pub const setentry = extern struct {
    key: [*c]PyObject = null,
    hash: Py_hash_t = 0,
};
pub const PySetObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    fill: Py_ssize_t = 0,
    used: Py_ssize_t = 0,
    mask: Py_ssize_t = 0,
    table: [*c]setentry = null,
    hash: Py_hash_t = 0,
    finger: Py_ssize_t = 0,
    smalltable: [8]setentry = @import("std").mem.zeroes([8]setentry),
    weakreflist: [*c]PyObject = null,
};
pub fn PySet_GET_SIZE(arg_so: [*c]PyObject) callconv(.c) Py_ssize_t {
    var so = arg_so;
    _ = &so;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PySetObject, @ptrCast(@alignCast(so)));
    }).*.used;
}
pub extern var PyCFunction_Type: PyTypeObject;
pub const PyCFunctionFast = ?*const fn ([*c]PyObject, [*c]const [*c]PyObject, Py_ssize_t) callconv(.c) [*c]PyObject;
pub const PyCFunctionWithKeywords = ?*const fn ([*c]PyObject, [*c]PyObject, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const PyCFunctionFastWithKeywords = ?*const fn ([*c]PyObject, [*c]const [*c]PyObject, Py_ssize_t, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const PyCMethod = ?*const fn ([*c]PyObject, [*c]PyTypeObject, [*c]const [*c]PyObject, Py_ssize_t, [*c]PyObject) callconv(.c) [*c]PyObject;
pub const _PyCFunctionFast = PyCFunctionFast;
pub const _PyCFunctionFastWithKeywords = PyCFunctionFastWithKeywords;
pub extern fn PyCFunction_GetFunction([*c]PyObject) PyCFunction;
pub extern fn PyCFunction_GetSelf([*c]PyObject) [*c]PyObject;
pub extern fn PyCFunction_GetFlags([*c]PyObject) c_int;
pub extern fn PyCFunction_New([*c]PyMethodDef, [*c]PyObject) [*c]PyObject;
pub extern fn PyCFunction_NewEx([*c]PyMethodDef, [*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyCMethod_New([*c]PyMethodDef, [*c]PyObject, [*c]PyObject, [*c]PyTypeObject) [*c]PyObject;
pub const PyCFunctionObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    m_ml: [*c]PyMethodDef = null,
    m_self: [*c]PyObject = null,
    m_module: [*c]PyObject = null,
    m_weakreflist: [*c]PyObject = null,
    vectorcall: vectorcallfunc = null,
};
pub const PyCMethodObject = extern struct {
    func: PyCFunctionObject = @import("std").mem.zeroes(PyCFunctionObject),
    mm_class: [*c]PyTypeObject = null,
};
pub extern var PyCMethod_Type: PyTypeObject;
pub fn PyCFunction_GET_FUNCTION(arg_func: [*c]PyObject) callconv(.c) PyCFunction {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyCFunctionObject, @ptrCast(@alignCast(func)));
    }).*.m_ml.*.ml_meth;
}
pub fn PyCFunction_GET_SELF(arg_func_obj: [*c]PyObject) callconv(.c) [*c]PyObject {
    var func_obj = arg_func_obj;
    _ = &func_obj;
    var func: [*c]PyCFunctionObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyCFunctionObject, @ptrCast(@alignCast(func_obj)));
    };
    _ = &func;
    if ((func.*.m_ml.*.ml_flags & METH_STATIC) != 0) {
        return null;
    }
    return func.*.m_self;
}
pub fn PyCFunction_GET_FLAGS(arg_func: [*c]PyObject) callconv(.c) c_int {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyCFunctionObject, @ptrCast(@alignCast(func)));
    }).*.m_ml.*.ml_flags;
}
pub fn PyCFunction_GET_CLASS(arg_func_obj: [*c]PyObject) callconv(.c) [*c]PyTypeObject {
    var func_obj = arg_func_obj;
    _ = &func_obj;
    var func: [*c]PyCFunctionObject = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyCFunctionObject, @ptrCast(@alignCast(func_obj)));
    };
    _ = &func;
    if ((func.*.m_ml.*.ml_flags & METH_METHOD) != 0) {
        return (blk: {
            _ = @as(c_int, 0);
            break :blk @as([*c]PyCMethodObject, @ptrCast(@alignCast(func)));
        }).*.mm_class;
    }
    return null;
}
pub extern var PyModule_Type: PyTypeObject;
pub extern fn PyModule_NewObject(name: [*c]PyObject) [*c]PyObject;
pub extern fn PyModule_New(name: [*c]const u8) [*c]PyObject;
pub extern fn PyModule_GetDict([*c]PyObject) [*c]PyObject;
pub extern fn PyModule_GetNameObject([*c]PyObject) [*c]PyObject;
pub extern fn PyModule_GetName([*c]PyObject) [*c]const u8;
pub extern fn PyModule_GetFilename([*c]PyObject) [*c]const u8;
pub extern fn PyModule_GetFilenameObject([*c]PyObject) [*c]PyObject;
pub extern fn PyModule_GetDef([*c]PyObject) [*c]PyModuleDef;
pub extern fn PyModule_GetState([*c]PyObject) ?*anyopaque;
pub extern fn PyModuleDef_Init([*c]PyModuleDef) [*c]PyObject;
pub extern var PyModuleDef_Type: PyTypeObject;
pub const struct__PyMonitoringState = extern struct {
    active: u8 = 0,
    @"opaque": u8 = 0,
    pub const PyMonitoring_EnterScope = __root.PyMonitoring_EnterScope;
    pub const _PyMonitoring_FirePyStartEvent = __root._PyMonitoring_FirePyStartEvent;
    pub const _PyMonitoring_FirePyResumeEvent = __root._PyMonitoring_FirePyResumeEvent;
    pub const _PyMonitoring_FirePyReturnEvent = __root._PyMonitoring_FirePyReturnEvent;
    pub const _PyMonitoring_FirePyYieldEvent = __root._PyMonitoring_FirePyYieldEvent;
    pub const _PyMonitoring_FireCallEvent = __root._PyMonitoring_FireCallEvent;
    pub const _PyMonitoring_FireLineEvent = __root._PyMonitoring_FireLineEvent;
    pub const _PyMonitoring_FireJumpEvent = __root._PyMonitoring_FireJumpEvent;
    pub const _PyMonitoring_FireBranchEvent = __root._PyMonitoring_FireBranchEvent;
    pub const _PyMonitoring_FireBranchRightEvent = __root._PyMonitoring_FireBranchRightEvent;
    pub const _PyMonitoring_FireBranchLeftEvent = __root._PyMonitoring_FireBranchLeftEvent;
    pub const _PyMonitoring_FireCReturnEvent = __root._PyMonitoring_FireCReturnEvent;
    pub const _PyMonitoring_FirePyThrowEvent = __root._PyMonitoring_FirePyThrowEvent;
    pub const _PyMonitoring_FireRaiseEvent = __root._PyMonitoring_FireRaiseEvent;
    pub const _PyMonitoring_FireReraiseEvent = __root._PyMonitoring_FireReraiseEvent;
    pub const _PyMonitoring_FireExceptionHandledEvent = __root._PyMonitoring_FireExceptionHandledEvent;
    pub const _PyMonitoring_FireCRaiseEvent = __root._PyMonitoring_FireCRaiseEvent;
    pub const _PyMonitoring_FirePyUnwindEvent = __root._PyMonitoring_FirePyUnwindEvent;
    pub const _PyMonitoring_FireStopIterationEvent = __root._PyMonitoring_FireStopIterationEvent;
    pub const PyMonitoring_FirePyStartEvent = __root.PyMonitoring_FirePyStartEvent;
    pub const PyMonitoring_FirePyResumeEvent = __root.PyMonitoring_FirePyResumeEvent;
    pub const PyMonitoring_FirePyReturnEvent = __root.PyMonitoring_FirePyReturnEvent;
    pub const PyMonitoring_FirePyYieldEvent = __root.PyMonitoring_FirePyYieldEvent;
    pub const PyMonitoring_FireCallEvent = __root.PyMonitoring_FireCallEvent;
    pub const PyMonitoring_FireLineEvent = __root.PyMonitoring_FireLineEvent;
    pub const PyMonitoring_FireJumpEvent = __root.PyMonitoring_FireJumpEvent;
    pub const PyMonitoring_FireBranchRightEvent = __root.PyMonitoring_FireBranchRightEvent;
    pub const PyMonitoring_FireBranchLeftEvent = __root.PyMonitoring_FireBranchLeftEvent;
    pub const PyMonitoring_FireCReturnEvent = __root.PyMonitoring_FireCReturnEvent;
    pub const PyMonitoring_FirePyThrowEvent = __root.PyMonitoring_FirePyThrowEvent;
    pub const PyMonitoring_FireRaiseEvent = __root.PyMonitoring_FireRaiseEvent;
    pub const PyMonitoring_FireReraiseEvent = __root.PyMonitoring_FireReraiseEvent;
    pub const PyMonitoring_FireExceptionHandledEvent = __root.PyMonitoring_FireExceptionHandledEvent;
    pub const PyMonitoring_FireCRaiseEvent = __root.PyMonitoring_FireCRaiseEvent;
    pub const PyMonitoring_FirePyUnwindEvent = __root.PyMonitoring_FirePyUnwindEvent;
    pub const PyMonitoring_FireStopIterationEvent = __root.PyMonitoring_FireStopIterationEvent;
    pub const EnterScope = __root.PyMonitoring_EnterScope;
    pub const FirePyStartEvent = __root._PyMonitoring_FirePyStartEvent;
    pub const FirePyResumeEvent = __root._PyMonitoring_FirePyResumeEvent;
    pub const FirePyReturnEvent = __root._PyMonitoring_FirePyReturnEvent;
    pub const FirePyYieldEvent = __root._PyMonitoring_FirePyYieldEvent;
    pub const FireCallEvent = __root._PyMonitoring_FireCallEvent;
    pub const FireLineEvent = __root._PyMonitoring_FireLineEvent;
    pub const FireJumpEvent = __root._PyMonitoring_FireJumpEvent;
    pub const FireBranchEvent = __root._PyMonitoring_FireBranchEvent;
    pub const FireBranchRightEvent = __root._PyMonitoring_FireBranchRightEvent;
    pub const FireBranchLeftEvent = __root._PyMonitoring_FireBranchLeftEvent;
    pub const FireCReturnEvent = __root._PyMonitoring_FireCReturnEvent;
    pub const FirePyThrowEvent = __root._PyMonitoring_FirePyThrowEvent;
    pub const FireRaiseEvent = __root._PyMonitoring_FireRaiseEvent;
    pub const FireReraiseEvent = __root._PyMonitoring_FireReraiseEvent;
    pub const FireExceptionHandledEvent = __root._PyMonitoring_FireExceptionHandledEvent;
    pub const FireCRaiseEvent = __root._PyMonitoring_FireCRaiseEvent;
    pub const FirePyUnwindEvent = __root._PyMonitoring_FirePyUnwindEvent;
    pub const FireStopIterationEvent = __root._PyMonitoring_FireStopIterationEvent;
};
pub const PyMonitoringState = struct__PyMonitoringState;
pub extern fn PyMonitoring_EnterScope(state_array: [*c]PyMonitoringState, version: [*c]u64, event_types: [*c]const u8, length: Py_ssize_t) c_int;
pub extern fn PyMonitoring_ExitScope() c_int;
pub extern fn _PyMonitoring_FirePyStartEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32) c_int;
pub extern fn _PyMonitoring_FirePyResumeEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32) c_int;
pub extern fn _PyMonitoring_FirePyReturnEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, retval: [*c]PyObject) c_int;
pub extern fn _PyMonitoring_FirePyYieldEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, retval: [*c]PyObject) c_int;
pub extern fn _PyMonitoring_FireCallEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, callable: [*c]PyObject, arg0: [*c]PyObject) c_int;
pub extern fn _PyMonitoring_FireLineEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, lineno: c_int) c_int;
pub extern fn _PyMonitoring_FireJumpEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, target_offset: [*c]PyObject) c_int;
pub extern fn _PyMonitoring_FireBranchEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, target_offset: [*c]PyObject) c_int;
pub extern fn _PyMonitoring_FireBranchRightEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, target_offset: [*c]PyObject) c_int;
pub extern fn _PyMonitoring_FireBranchLeftEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, target_offset: [*c]PyObject) c_int;
pub extern fn _PyMonitoring_FireCReturnEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, retval: [*c]PyObject) c_int;
pub extern fn _PyMonitoring_FirePyThrowEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32) c_int;
pub extern fn _PyMonitoring_FireRaiseEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32) c_int;
pub extern fn _PyMonitoring_FireReraiseEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32) c_int;
pub extern fn _PyMonitoring_FireExceptionHandledEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32) c_int;
pub extern fn _PyMonitoring_FireCRaiseEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32) c_int;
pub extern fn _PyMonitoring_FirePyUnwindEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32) c_int;
pub extern fn _PyMonitoring_FireStopIterationEvent(state: [*c]PyMonitoringState, codelike: [*c]PyObject, offset: i32, value: [*c]PyObject) c_int;
pub fn PyMonitoring_FirePyStartEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FirePyStartEvent(state, codelike, offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FirePyResumeEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FirePyResumeEvent(state, codelike, offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FirePyReturnEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_retval: [*c]PyObject) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var retval = arg_retval;
    _ = &retval;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FirePyReturnEvent(state, codelike, offset, retval);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FirePyYieldEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_retval: [*c]PyObject) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var retval = arg_retval;
    _ = &retval;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FirePyYieldEvent(state, codelike, offset, retval);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireCallEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_callable: [*c]PyObject, arg_arg0: [*c]PyObject) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var callable = arg_callable;
    _ = &callable;
    var arg0 = arg_arg0;
    _ = &arg0;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireCallEvent(state, codelike, offset, callable, arg0);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireLineEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_lineno: c_int) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var lineno = arg_lineno;
    _ = &lineno;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireLineEvent(state, codelike, offset, lineno);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireJumpEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_target_offset: [*c]PyObject) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var target_offset = arg_target_offset;
    _ = &target_offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireJumpEvent(state, codelike, offset, target_offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireBranchRightEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_target_offset: [*c]PyObject) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var target_offset = arg_target_offset;
    _ = &target_offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireBranchRightEvent(state, codelike, offset, target_offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireBranchLeftEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_target_offset: [*c]PyObject) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var target_offset = arg_target_offset;
    _ = &target_offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireBranchLeftEvent(state, codelike, offset, target_offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireCReturnEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_retval: [*c]PyObject) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var retval = arg_retval;
    _ = &retval;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireCReturnEvent(state, codelike, offset, retval);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FirePyThrowEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FirePyThrowEvent(state, codelike, offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireRaiseEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireRaiseEvent(state, codelike, offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireReraiseEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireReraiseEvent(state, codelike, offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireExceptionHandledEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireExceptionHandledEvent(state, codelike, offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireCRaiseEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireCRaiseEvent(state, codelike, offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FirePyUnwindEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FirePyUnwindEvent(state, codelike, offset);
    } else {
        return 0;
    }
    return undefined;
}
pub fn PyMonitoring_FireStopIterationEvent(arg_state: [*c]PyMonitoringState, arg_codelike: [*c]PyObject, arg_offset: i32, arg_value: [*c]PyObject) callconv(.c) c_int {
    var state = arg_state;
    _ = &state;
    var codelike = arg_codelike;
    _ = &codelike;
    var offset = arg_offset;
    _ = &offset;
    var value = arg_value;
    _ = &value;
    if (@as(c_int, state.*.active) != 0) {
        return _PyMonitoring_FireStopIterationEvent(state, codelike, offset, value);
    } else {
        return 0;
    }
    return undefined;
}
pub const PyFrameConstructor = extern struct {
    fc_globals: [*c]PyObject = null,
    fc_builtins: [*c]PyObject = null,
    fc_name: [*c]PyObject = null,
    fc_qualname: [*c]PyObject = null,
    fc_code: [*c]PyObject = null,
    fc_defaults: [*c]PyObject = null,
    fc_kwdefaults: [*c]PyObject = null,
    fc_closure: [*c]PyObject = null,
};
pub const PyFunctionObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    func_globals: [*c]PyObject = null,
    func_builtins: [*c]PyObject = null,
    func_name: [*c]PyObject = null,
    func_qualname: [*c]PyObject = null,
    func_code: [*c]PyObject = null,
    func_defaults: [*c]PyObject = null,
    func_kwdefaults: [*c]PyObject = null,
    func_closure: [*c]PyObject = null,
    func_doc: [*c]PyObject = null,
    func_dict: [*c]PyObject = null,
    func_weakreflist: [*c]PyObject = null,
    func_module: [*c]PyObject = null,
    func_annotations: [*c]PyObject = null,
    func_annotate: [*c]PyObject = null,
    func_typeparams: [*c]PyObject = null,
    vectorcall: vectorcallfunc = null,
    func_version: u32 = 0,
    pub const PyFunction_SetVectorcall = __root.PyFunction_SetVectorcall;
    pub const SetVectorcall = __root.PyFunction_SetVectorcall;
};
pub extern var PyFunction_Type: PyTypeObject;
pub extern fn PyFunction_New([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_NewWithQualName([*c]PyObject, [*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_GetCode([*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_GetGlobals([*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_GetModule([*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_GetDefaults([*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_SetDefaults([*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyFunction_SetVectorcall([*c]PyFunctionObject, vectorcallfunc) void;
pub extern fn PyFunction_GetKwDefaults([*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_SetKwDefaults([*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyFunction_GetClosure([*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_SetClosure([*c]PyObject, [*c]PyObject) c_int;
pub extern fn PyFunction_GetAnnotations([*c]PyObject) [*c]PyObject;
pub extern fn PyFunction_SetAnnotations([*c]PyObject, [*c]PyObject) c_int;
pub fn PyFunction_GET_CODE(arg_func: [*c]PyObject) callconv(.c) [*c]PyObject {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyFunctionObject, @ptrCast(@alignCast(func)));
    }).*.func_code;
}
pub fn PyFunction_GET_GLOBALS(arg_func: [*c]PyObject) callconv(.c) [*c]PyObject {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyFunctionObject, @ptrCast(@alignCast(func)));
    }).*.func_globals;
}
pub fn PyFunction_GET_MODULE(arg_func: [*c]PyObject) callconv(.c) [*c]PyObject {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyFunctionObject, @ptrCast(@alignCast(func)));
    }).*.func_module;
}
pub fn PyFunction_GET_DEFAULTS(arg_func: [*c]PyObject) callconv(.c) [*c]PyObject {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyFunctionObject, @ptrCast(@alignCast(func)));
    }).*.func_defaults;
}
pub fn PyFunction_GET_KW_DEFAULTS(arg_func: [*c]PyObject) callconv(.c) [*c]PyObject {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyFunctionObject, @ptrCast(@alignCast(func)));
    }).*.func_kwdefaults;
}
pub fn PyFunction_GET_CLOSURE(arg_func: [*c]PyObject) callconv(.c) [*c]PyObject {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyFunctionObject, @ptrCast(@alignCast(func)));
    }).*.func_closure;
}
pub fn PyFunction_GET_ANNOTATIONS(arg_func: [*c]PyObject) callconv(.c) [*c]PyObject {
    var func = arg_func;
    _ = &func;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyFunctionObject, @ptrCast(@alignCast(func)));
    }).*.func_annotations;
}
pub extern var PyClassMethod_Type: PyTypeObject;
pub extern var PyStaticMethod_Type: PyTypeObject;
pub extern fn PyClassMethod_New([*c]PyObject) [*c]PyObject;
pub extern fn PyStaticMethod_New([*c]PyObject) [*c]PyObject;
pub const PyFunction_EVENT_CREATE: c_int = 0;
pub const PyFunction_EVENT_DESTROY: c_int = 1;
pub const PyFunction_EVENT_MODIFY_CODE: c_int = 2;
pub const PyFunction_EVENT_MODIFY_DEFAULTS: c_int = 3;
pub const PyFunction_EVENT_MODIFY_KWDEFAULTS: c_int = 4;
pub const PyFunction_WatchEvent = c_uint;
pub const PyFunction_WatchCallback = ?*const fn (event: PyFunction_WatchEvent, func: [*c]PyFunctionObject, new_value: [*c]PyObject) callconv(.c) c_int;
pub extern fn PyFunction_AddWatcher(callback: PyFunction_WatchCallback) c_int;
pub extern fn PyFunction_ClearWatcher(watcher_id: c_int) c_int;
pub const PyMethodObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    im_func: [*c]PyObject = null,
    im_self: [*c]PyObject = null,
    im_weakreflist: [*c]PyObject = null,
    vectorcall: vectorcallfunc = null,
};
pub extern var PyMethod_Type: PyTypeObject;
pub extern fn PyMethod_New([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyMethod_Function([*c]PyObject) [*c]PyObject;
pub extern fn PyMethod_Self([*c]PyObject) [*c]PyObject;
pub fn PyMethod_GET_FUNCTION(arg_meth: [*c]PyObject) callconv(.c) [*c]PyObject {
    var meth = arg_meth;
    _ = &meth;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyMethodObject, @ptrCast(@alignCast(meth)));
    }).*.im_func;
}
pub fn PyMethod_GET_SELF(arg_meth: [*c]PyObject) callconv(.c) [*c]PyObject {
    var meth = arg_meth;
    _ = &meth;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyMethodObject, @ptrCast(@alignCast(meth)));
    }).*.im_self;
}
pub const PyInstanceMethodObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    func: [*c]PyObject = null,
};
pub extern var PyInstanceMethod_Type: PyTypeObject;
pub extern fn PyInstanceMethod_New([*c]PyObject) [*c]PyObject;
pub extern fn PyInstanceMethod_Function([*c]PyObject) [*c]PyObject;
pub fn PyInstanceMethod_GET_FUNCTION(arg_meth: [*c]PyObject) callconv(.c) [*c]PyObject {
    var meth = arg_meth;
    _ = &meth;
    return (blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyInstanceMethodObject, @ptrCast(@alignCast(meth)));
    }).*.func;
}
pub extern fn PyFile_FromFd(c_int, [*c]const u8, [*c]const u8, c_int, [*c]const u8, [*c]const u8, [*c]const u8, c_int) [*c]PyObject;
pub extern fn PyFile_GetLine([*c]PyObject, c_int) [*c]PyObject;
pub extern fn PyFile_WriteObject([*c]PyObject, [*c]PyObject, c_int) c_int;
pub extern fn PyFile_WriteString([*c]const u8, [*c]PyObject) c_int;
pub extern fn PyObject_AsFileDescriptor([*c]PyObject) c_int;
pub extern var Py_FileSystemDefaultEncoding: [*c]const u8;
pub extern var Py_FileSystemDefaultEncodeErrors: [*c]const u8;
pub extern var Py_HasFileSystemDefaultEncoding: c_int;
pub extern var Py_UTF8Mode: c_int;
pub extern fn Py_UniversalNewlineFgets([*c]u8, c_int, [*c]FILE, [*c]PyObject) [*c]u8;
pub extern fn PyFile_NewStdPrinter(c_int) [*c]PyObject;
pub extern var PyStdPrinter_Type: PyTypeObject;
pub const Py_OpenCodeHookFunction = ?*const fn ([*c]PyObject, ?*anyopaque) callconv(.c) [*c]PyObject;
pub extern fn PyFile_OpenCode(utf8path: [*c]const u8) [*c]PyObject;
pub extern fn PyFile_OpenCodeObject(path: [*c]PyObject) [*c]PyObject;
pub extern fn PyFile_SetOpenCodeHook(hook: Py_OpenCodeHookFunction, userData: ?*anyopaque) c_int;
pub extern var PyCapsule_Type: PyTypeObject;
pub const PyCapsule_Destructor = ?*const fn ([*c]PyObject) callconv(.c) void;
pub extern fn PyCapsule_New(pointer: ?*anyopaque, name: [*c]const u8, destructor: PyCapsule_Destructor) [*c]PyObject;
pub extern fn PyCapsule_GetPointer(capsule: [*c]PyObject, name: [*c]const u8) ?*anyopaque;
pub extern fn PyCapsule_GetDestructor(capsule: [*c]PyObject) PyCapsule_Destructor;
pub extern fn PyCapsule_GetName(capsule: [*c]PyObject) [*c]const u8;
pub extern fn PyCapsule_GetContext(capsule: [*c]PyObject) ?*anyopaque;
pub extern fn PyCapsule_IsValid(capsule: [*c]PyObject, name: [*c]const u8) c_int;
pub extern fn PyCapsule_SetPointer(capsule: [*c]PyObject, pointer: ?*anyopaque) c_int;
pub extern fn PyCapsule_SetDestructor(capsule: [*c]PyObject, destructor: PyCapsule_Destructor) c_int;
pub extern fn PyCapsule_SetName(capsule: [*c]PyObject, name: [*c]const u8) c_int;
pub extern fn PyCapsule_SetContext(capsule: [*c]PyObject, context: ?*anyopaque) c_int;
pub extern fn PyCapsule_Import(name: [*c]const u8, no_block: c_int) ?*anyopaque;
pub const _PyCoCached = extern struct {
    _co_code: [*c]PyObject = null,
    _co_varnames: [*c]PyObject = null,
    _co_cellvars: [*c]PyObject = null,
    _co_freevars: [*c]PyObject = null,
};
pub const struct__PyExecutorObject_18 = opaque {};
pub const _PyExecutorArray = extern struct {
    size: c_int = 0,
    capacity: c_int = 0,
    executors: [1]?*struct__PyExecutorObject_18 = @import("std").mem.zeroes([1]?*struct__PyExecutorObject_18),
};
pub extern var PyCode_Type: PyTypeObject;
pub fn PyCode_GetNumFree(arg_op: [*c]PyCodeObject) callconv(.c) Py_ssize_t {
    var op = arg_op;
    _ = &op;
    _ = @as(c_int, 0);
    return op.*.co_nfreevars;
}
pub fn PyUnstable_Code_GetFirstFree(arg_op: [*c]PyCodeObject) callconv(.c) c_int {
    var op = arg_op;
    _ = &op;
    _ = @as(c_int, 0);
    return op.*.co_nlocalsplus - op.*.co_nfreevars;
}
pub fn PyCode_GetFirstFree(arg_op: [*c]PyCodeObject) callconv(.c) c_int {
    var op = arg_op;
    _ = &op;
    return PyUnstable_Code_GetFirstFree(op);
}
pub extern fn PyUnstable_Code_New(c_int, c_int, c_int, c_int, c_int, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, c_int, [*c]PyObject, [*c]PyObject) [*c]PyCodeObject;
pub extern fn PyUnstable_Code_NewWithPosOnlyArgs(c_int, c_int, c_int, c_int, c_int, c_int, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, [*c]PyObject, c_int, [*c]PyObject, [*c]PyObject) [*c]PyCodeObject;
pub fn PyCode_New(arg_a: c_int, arg_b: c_int, arg_c: c_int, arg_d: c_int, arg_e: c_int, arg_f: [*c]PyObject, arg_g: [*c]PyObject, arg_h: [*c]PyObject, arg_i: [*c]PyObject, arg_j: [*c]PyObject, arg_k: [*c]PyObject, arg_l: [*c]PyObject, arg_m: [*c]PyObject, arg_n: [*c]PyObject, arg_o: c_int, arg_p: [*c]PyObject, arg_q: [*c]PyObject) callconv(.c) [*c]PyCodeObject {
    var a = arg_a;
    _ = &a;
    var b = arg_b;
    _ = &b;
    var c = arg_c;
    _ = &c;
    var d = arg_d;
    _ = &d;
    var e = arg_e;
    _ = &e;
    var f = arg_f;
    _ = &f;
    var g = arg_g;
    _ = &g;
    var h = arg_h;
    _ = &h;
    var i = arg_i;
    _ = &i;
    var j = arg_j;
    _ = &j;
    var k = arg_k;
    _ = &k;
    var l = arg_l;
    _ = &l;
    var m = arg_m;
    _ = &m;
    var n = arg_n;
    _ = &n;
    var o = arg_o;
    _ = &o;
    var p = arg_p;
    _ = &p;
    var q = arg_q;
    _ = &q;
    return PyUnstable_Code_New(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q);
}
pub fn PyCode_NewWithPosOnlyArgs(arg_a: c_int, arg_poac: c_int, arg_b: c_int, arg_c: c_int, arg_d: c_int, arg_e: c_int, arg_f: [*c]PyObject, arg_g: [*c]PyObject, arg_h: [*c]PyObject, arg_i: [*c]PyObject, arg_j: [*c]PyObject, arg_k: [*c]PyObject, arg_l: [*c]PyObject, arg_m: [*c]PyObject, arg_n: [*c]PyObject, arg_o: c_int, arg_p: [*c]PyObject, arg_q: [*c]PyObject) callconv(.c) [*c]PyCodeObject {
    var a = arg_a;
    _ = &a;
    var poac = arg_poac;
    _ = &poac;
    var b = arg_b;
    _ = &b;
    var c = arg_c;
    _ = &c;
    var d = arg_d;
    _ = &d;
    var e = arg_e;
    _ = &e;
    var f = arg_f;
    _ = &f;
    var g = arg_g;
    _ = &g;
    var h = arg_h;
    _ = &h;
    var i = arg_i;
    _ = &i;
    var j = arg_j;
    _ = &j;
    var k = arg_k;
    _ = &k;
    var l = arg_l;
    _ = &l;
    var m = arg_m;
    _ = &m;
    var n = arg_n;
    _ = &n;
    var o = arg_o;
    _ = &o;
    var p = arg_p;
    _ = &p;
    var q = arg_q;
    _ = &q;
    return PyUnstable_Code_NewWithPosOnlyArgs(a, poac, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q);
}
pub extern fn PyCode_NewEmpty(filename: [*c]const u8, funcname: [*c]const u8, firstlineno: c_int) [*c]PyCodeObject;
pub extern fn PyCode_Addr2Line([*c]PyCodeObject, c_int) c_int;
pub extern fn PyCode_Addr2Location([*c]PyCodeObject, c_int, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_int) c_int;
pub const PY_CODE_EVENT_CREATE: c_int = 0;
pub const PY_CODE_EVENT_DESTROY: c_int = 1;
pub const PyCodeEvent = c_uint;
pub const PyCode_WatchCallback = ?*const fn (event: PyCodeEvent, co: [*c]PyCodeObject) callconv(.c) c_int;
pub extern fn PyCode_AddWatcher(callback: PyCode_WatchCallback) c_int;
pub extern fn PyCode_ClearWatcher(watcher_id: c_int) c_int;
pub const struct__opaque = extern struct {
    computed_line: c_int = 0,
    lo_next: [*c]const u8 = null,
    limit: [*c]const u8 = null,
};
pub const struct__line_offsets = extern struct {
    ar_start: c_int = 0,
    ar_end: c_int = 0,
    ar_line: c_int = 0,
    @"opaque": struct__opaque = @import("std").mem.zeroes(struct__opaque),
};
pub const PyCodeAddressRange = struct__line_offsets;
pub extern fn _PyCode_CheckLineNumber(lasti: c_int, bounds: [*c]PyCodeAddressRange) c_int;
pub extern fn _PyCode_ConstantKey(obj: [*c]PyObject) [*c]PyObject;
pub extern fn PyCode_Optimize(code: [*c]PyObject, consts: [*c]PyObject, names: [*c]PyObject, lnotab: [*c]PyObject) [*c]PyObject;
pub extern fn PyUnstable_Code_GetExtra(code: [*c]PyObject, index: Py_ssize_t, extra: [*c]?*anyopaque) c_int;
pub extern fn PyUnstable_Code_SetExtra(code: [*c]PyObject, index: Py_ssize_t, extra: ?*anyopaque) c_int;
pub fn _PyCode_GetExtra(arg_code: [*c]PyObject, arg_index_1: Py_ssize_t, arg_extra: [*c]?*anyopaque) callconv(.c) c_int {
    var code = arg_code;
    _ = &code;
    var index_1 = arg_index_1;
    _ = &index_1;
    var extra = arg_extra;
    _ = &extra;
    return PyUnstable_Code_GetExtra(code, index_1, extra);
}
pub fn _PyCode_SetExtra(arg_code: [*c]PyObject, arg_index_1: Py_ssize_t, arg_extra: ?*anyopaque) callconv(.c) c_int {
    var code = arg_code;
    _ = &code;
    var index_1 = arg_index_1;
    _ = &index_1;
    var extra = arg_extra;
    _ = &extra;
    return PyUnstable_Code_SetExtra(code, index_1, extra);
}
pub extern fn PyCode_GetCode(code: [*c]PyCodeObject) [*c]PyObject;
pub extern fn PyCode_GetVarnames(code: [*c]PyCodeObject) [*c]PyObject;
pub extern fn PyCode_GetCellvars(code: [*c]PyCodeObject) [*c]PyObject;
pub extern fn PyCode_GetFreevars(code: [*c]PyCodeObject) [*c]PyObject;
pub const PY_CODE_LOCATION_INFO_SHORT0: c_int = 0;
pub const PY_CODE_LOCATION_INFO_ONE_LINE0: c_int = 10;
pub const PY_CODE_LOCATION_INFO_ONE_LINE1: c_int = 11;
pub const PY_CODE_LOCATION_INFO_ONE_LINE2: c_int = 12;
pub const PY_CODE_LOCATION_INFO_NO_COLUMNS: c_int = 13;
pub const PY_CODE_LOCATION_INFO_LONG: c_int = 14;
pub const PY_CODE_LOCATION_INFO_NONE: c_int = 15;
pub const enum__PyCodeLocationInfoKind = c_uint;
pub const _PyCodeLocationInfoKind = enum__PyCodeLocationInfoKind;
pub extern fn PyFrame_GetLineNumber(?*PyFrameObject) c_int;
pub extern fn PyFrame_GetCode(frame: ?*PyFrameObject) [*c]PyCodeObject;
pub extern var PyFrame_Type: PyTypeObject;
pub extern var PyFrameLocalsProxy_Type: PyTypeObject;
pub extern fn PyFrame_GetBack(frame: ?*PyFrameObject) ?*PyFrameObject;
pub extern fn PyFrame_GetLocals(frame: ?*PyFrameObject) [*c]PyObject;
pub extern fn PyFrame_GetGlobals(frame: ?*PyFrameObject) [*c]PyObject;
pub extern fn PyFrame_GetBuiltins(frame: ?*PyFrameObject) [*c]PyObject;
pub extern fn PyFrame_GetGenerator(frame: ?*PyFrameObject) [*c]PyObject;
pub extern fn PyFrame_GetLasti(frame: ?*PyFrameObject) c_int;
pub extern fn PyFrame_GetVar(frame: ?*PyFrameObject, name: [*c]PyObject) [*c]PyObject;
pub extern fn PyFrame_GetVarString(frame: ?*PyFrameObject, name: [*c]const u8) [*c]PyObject;
pub const struct__PyInterpreterFrame = opaque {
    pub const PyUnstable_InterpreterFrame_GetCode = __root.PyUnstable_InterpreterFrame_GetCode;
    pub const PyUnstable_InterpreterFrame_GetLasti = __root.PyUnstable_InterpreterFrame_GetLasti;
    pub const PyUnstable_InterpreterFrame_GetLine = __root.PyUnstable_InterpreterFrame_GetLine;
    pub const GetCode = __root.PyUnstable_InterpreterFrame_GetCode;
    pub const GetLasti = __root.PyUnstable_InterpreterFrame_GetLasti;
    pub const GetLine = __root.PyUnstable_InterpreterFrame_GetLine;
};
pub extern fn PyUnstable_InterpreterFrame_GetCode(frame: ?*struct__PyInterpreterFrame) [*c]PyObject;
pub extern fn PyUnstable_InterpreterFrame_GetLasti(frame: ?*struct__PyInterpreterFrame) c_int;
pub extern fn PyUnstable_InterpreterFrame_GetLine(frame: ?*struct__PyInterpreterFrame) c_int;
pub extern const PyUnstable_ExecutableKinds: [6][*c]const PyTypeObject;
pub extern fn PyTraceBack_Here(?*PyFrameObject) c_int;
pub extern fn PyTraceBack_Print([*c]PyObject, [*c]PyObject) c_int;
pub extern var PyTraceBack_Type: PyTypeObject;
pub const PyTracebackObject = struct__traceback;
pub const struct__traceback = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    tb_next: [*c]PyTracebackObject = null,
    tb_frame: ?*PyFrameObject = null,
    tb_lasti: c_int = 0,
    tb_lineno: c_int = 0,
};
pub extern var _Py_EllipsisObject: PyObject;
pub const PySliceObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    start: [*c]PyObject = null,
    stop: [*c]PyObject = null,
    step: [*c]PyObject = null,
    pub const _PySlice_GetLongIndices = __root._PySlice_GetLongIndices;
    pub const GetLongIndices = __root._PySlice_GetLongIndices;
};
pub extern var PySlice_Type: PyTypeObject;
pub extern var PyEllipsis_Type: PyTypeObject;
pub extern fn PySlice_New(start: [*c]PyObject, stop: [*c]PyObject, step: [*c]PyObject) [*c]PyObject;
pub extern fn _PySlice_FromIndices(start: Py_ssize_t, stop: Py_ssize_t) [*c]PyObject;
pub extern fn _PySlice_GetLongIndices(self: [*c]PySliceObject, length: [*c]PyObject, start_ptr: [*c][*c]PyObject, stop_ptr: [*c][*c]PyObject, step_ptr: [*c][*c]PyObject) c_int;
pub extern fn PySlice_GetIndices(r: [*c]PyObject, length: Py_ssize_t, start: [*c]Py_ssize_t, stop: [*c]Py_ssize_t, step: [*c]Py_ssize_t) c_int;
pub extern fn PySlice_GetIndicesEx(r: [*c]PyObject, length: Py_ssize_t, start: [*c]Py_ssize_t, stop: [*c]Py_ssize_t, step: [*c]Py_ssize_t, slicelength: [*c]Py_ssize_t) c_int;
pub extern fn PySlice_Unpack(slice: [*c]PyObject, start: [*c]Py_ssize_t, stop: [*c]Py_ssize_t, step: [*c]Py_ssize_t) c_int;
pub extern fn PySlice_AdjustIndices(length: Py_ssize_t, start: [*c]Py_ssize_t, stop: [*c]Py_ssize_t, step: Py_ssize_t) Py_ssize_t;
pub const PyCellObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    ob_ref: [*c]PyObject = null,
};
pub extern var PyCell_Type: PyTypeObject;
pub extern fn PyCell_New([*c]PyObject) [*c]PyObject;
pub extern fn PyCell_Get([*c]PyObject) [*c]PyObject;
pub extern fn PyCell_Set([*c]PyObject, [*c]PyObject) c_int;
pub fn PyCell_GET(arg_op: [*c]PyObject) callconv(.c) [*c]PyObject {
    var op = arg_op;
    _ = &op;
    var res: [*c]PyObject = undefined;
    _ = &res;
    var cell: [*c]PyCellObject = undefined;
    _ = &cell;
    _ = @as(c_int, 0);
    cell = @as([*c]PyCellObject, @ptrCast(@alignCast(op)));
    {
        res = cell.*.ob_ref;
    }
    return res;
}
pub fn PyCell_SET(arg_op: [*c]PyObject, arg_value: [*c]PyObject) callconv(.c) void {
    var op = arg_op;
    _ = &op;
    var value = arg_value;
    _ = &value;
    var cell: [*c]PyCellObject = undefined;
    _ = &cell;
    _ = @as(c_int, 0);
    cell = @as([*c]PyCellObject, @ptrCast(@alignCast(op)));
    {
        cell.*.ob_ref = value;
    }
}
pub extern var PySeqIter_Type: PyTypeObject;
pub extern var PyCallIter_Type: PyTypeObject;
pub extern fn PySeqIter_New([*c]PyObject) [*c]PyObject;
pub extern fn PyCallIter_New([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub const _PyStatus_TYPE_OK: c_int = 0;
pub const _PyStatus_TYPE_ERROR: c_int = 1;
pub const _PyStatus_TYPE_EXIT: c_int = 2;
const enum_unnamed_19 = c_uint;
pub const PyStatus = extern struct {
    _type: enum_unnamed_19 = @import("std").mem.zeroes(enum_unnamed_19),
    func: [*c]const u8 = null,
    err_msg: [*c]const u8 = null,
    exitcode: c_int = 0,
    pub const PyStatus_IsError = __root.PyStatus_IsError;
    pub const PyStatus_IsExit = __root.PyStatus_IsExit;
    pub const PyStatus_Exception = __root.PyStatus_Exception;
    pub const Py_ExitStatusException = __root.Py_ExitStatusException;
    pub const IsError = __root.PyStatus_IsError;
    pub const IsExit = __root.PyStatus_IsExit;
    pub const Exception = __root.PyStatus_Exception;
    pub const ExitStatusException = __root.Py_ExitStatusException;
};
pub extern fn PyStatus_Ok() PyStatus;
pub extern fn PyStatus_Error(err_msg: [*c]const u8) PyStatus;
pub extern fn PyStatus_NoMemory() PyStatus;
pub extern fn PyStatus_Exit(exitcode: c_int) PyStatus;
pub extern fn PyStatus_IsError(err: PyStatus) c_int;
pub extern fn PyStatus_IsExit(err: PyStatus) c_int;
pub extern fn PyStatus_Exception(err: PyStatus) c_int;
pub const PyWideStringList = extern struct {
    length: Py_ssize_t = 0,
    items: [*c][*c]wchar_t = null,
    pub const PyWideStringList_Append = __root.PyWideStringList_Append;
    pub const PyWideStringList_Insert = __root.PyWideStringList_Insert;
    pub const Append = __root.PyWideStringList_Append;
    pub const Insert = __root.PyWideStringList_Insert;
};
pub extern fn PyWideStringList_Append(list: [*c]PyWideStringList, item: [*c]const wchar_t) PyStatus;
pub extern fn PyWideStringList_Insert(list: [*c]PyWideStringList, index: Py_ssize_t, item: [*c]const wchar_t) PyStatus;
pub const struct_PyPreConfig = extern struct {
    _config_init: c_int = 0,
    parse_argv: c_int = 0,
    isolated: c_int = 0,
    use_environment: c_int = 0,
    configure_locale: c_int = 0,
    coerce_c_locale: c_int = 0,
    coerce_c_locale_warn: c_int = 0,
    utf8_mode: c_int = 0,
    dev_mode: c_int = 0,
    allocator: c_int = 0,
    pub const PyPreConfig_InitPythonConfig = __root.PyPreConfig_InitPythonConfig;
    pub const PyPreConfig_InitIsolatedConfig = __root.PyPreConfig_InitIsolatedConfig;
    pub const Py_PreInitialize = __root.Py_PreInitialize;
    pub const Py_PreInitializeFromBytesArgs = __root.Py_PreInitializeFromBytesArgs;
    pub const Py_PreInitializeFromArgs = __root.Py_PreInitializeFromArgs;
    pub const InitPythonConfig = __root.PyPreConfig_InitPythonConfig;
    pub const InitIsolatedConfig = __root.PyPreConfig_InitIsolatedConfig;
    pub const PreInitialize = __root.Py_PreInitialize;
    pub const PreInitializeFromBytesArgs = __root.Py_PreInitializeFromBytesArgs;
    pub const PreInitializeFromArgs = __root.Py_PreInitializeFromArgs;
};
pub const PyPreConfig = struct_PyPreConfig;
pub extern fn PyPreConfig_InitPythonConfig(config: [*c]PyPreConfig) void;
pub extern fn PyPreConfig_InitIsolatedConfig(config: [*c]PyPreConfig) void;
pub const struct_PyConfig = extern struct {
    _config_init: c_int = 0,
    isolated: c_int = 0,
    use_environment: c_int = 0,
    dev_mode: c_int = 0,
    install_signal_handlers: c_int = 0,
    use_hash_seed: c_int = 0,
    hash_seed: c_ulong = 0,
    faulthandler: c_int = 0,
    tracemalloc: c_int = 0,
    perf_profiling: c_int = 0,
    remote_debug: c_int = 0,
    import_time: c_int = 0,
    code_debug_ranges: c_int = 0,
    show_ref_count: c_int = 0,
    dump_refs: c_int = 0,
    dump_refs_file: [*c]wchar_t = null,
    malloc_stats: c_int = 0,
    filesystem_encoding: [*c]wchar_t = null,
    filesystem_errors: [*c]wchar_t = null,
    pycache_prefix: [*c]wchar_t = null,
    parse_argv: c_int = 0,
    orig_argv: PyWideStringList = @import("std").mem.zeroes(PyWideStringList),
    argv: PyWideStringList = @import("std").mem.zeroes(PyWideStringList),
    xoptions: PyWideStringList = @import("std").mem.zeroes(PyWideStringList),
    warnoptions: PyWideStringList = @import("std").mem.zeroes(PyWideStringList),
    site_import: c_int = 0,
    bytes_warning: c_int = 0,
    warn_default_encoding: c_int = 0,
    inspect: c_int = 0,
    interactive: c_int = 0,
    optimization_level: c_int = 0,
    parser_debug: c_int = 0,
    write_bytecode: c_int = 0,
    verbose: c_int = 0,
    quiet: c_int = 0,
    user_site_directory: c_int = 0,
    configure_c_stdio: c_int = 0,
    buffered_stdio: c_int = 0,
    stdio_encoding: [*c]wchar_t = null,
    stdio_errors: [*c]wchar_t = null,
    check_hash_pycs_mode: [*c]wchar_t = null,
    use_frozen_modules: c_int = 0,
    safe_path: c_int = 0,
    int_max_str_digits: c_int = 0,
    thread_inherit_context: c_int = 0,
    context_aware_warnings: c_int = 0,
    cpu_count: c_int = 0,
    pathconfig_warnings: c_int = 0,
    program_name: [*c]wchar_t = null,
    pythonpath_env: [*c]wchar_t = null,
    home: [*c]wchar_t = null,
    platlibdir: [*c]wchar_t = null,
    module_search_paths_set: c_int = 0,
    module_search_paths: PyWideStringList = @import("std").mem.zeroes(PyWideStringList),
    stdlib_dir: [*c]wchar_t = null,
    executable: [*c]wchar_t = null,
    base_executable: [*c]wchar_t = null,
    prefix: [*c]wchar_t = null,
    base_prefix: [*c]wchar_t = null,
    exec_prefix: [*c]wchar_t = null,
    base_exec_prefix: [*c]wchar_t = null,
    skip_source_first_line: c_int = 0,
    run_command: [*c]wchar_t = null,
    run_module: [*c]wchar_t = null,
    run_filename: [*c]wchar_t = null,
    sys_path_0: [*c]wchar_t = null,
    _install_importlib: c_int = 0,
    _init_main: c_int = 0,
    _is_python_build: c_int = 0,
    pub const PyConfig_InitPythonConfig = __root.PyConfig_InitPythonConfig;
    pub const PyConfig_InitIsolatedConfig = __root.PyConfig_InitIsolatedConfig;
    pub const PyConfig_Clear = __root.PyConfig_Clear;
    pub const PyConfig_SetString = __root.PyConfig_SetString;
    pub const PyConfig_SetBytesString = __root.PyConfig_SetBytesString;
    pub const PyConfig_Read = __root.PyConfig_Read;
    pub const PyConfig_SetBytesArgv = __root.PyConfig_SetBytesArgv;
    pub const PyConfig_SetArgv = __root.PyConfig_SetArgv;
    pub const PyConfig_SetWideStringList = __root.PyConfig_SetWideStringList;
    pub const Py_InitializeFromConfig = __root.Py_InitializeFromConfig;
    pub const InitPythonConfig = __root.PyConfig_InitPythonConfig;
    pub const InitIsolatedConfig = __root.PyConfig_InitIsolatedConfig;
    pub const Clear = __root.PyConfig_Clear;
    pub const SetString = __root.PyConfig_SetString;
    pub const SetBytesString = __root.PyConfig_SetBytesString;
    pub const Read = __root.PyConfig_Read;
    pub const SetBytesArgv = __root.PyConfig_SetBytesArgv;
    pub const SetArgv = __root.PyConfig_SetArgv;
    pub const SetWideStringList = __root.PyConfig_SetWideStringList;
    pub const InitializeFromConfig = __root.Py_InitializeFromConfig;
};
pub const PyConfig = struct_PyConfig;
pub extern fn PyConfig_InitPythonConfig(config: [*c]PyConfig) void;
pub extern fn PyConfig_InitIsolatedConfig(config: [*c]PyConfig) void;
pub extern fn PyConfig_Clear([*c]PyConfig) void;
pub extern fn PyConfig_SetString(config: [*c]PyConfig, config_str: [*c][*c]wchar_t, str: [*c]const wchar_t) PyStatus;
pub extern fn PyConfig_SetBytesString(config: [*c]PyConfig, config_str: [*c][*c]wchar_t, str: [*c]const u8) PyStatus;
pub extern fn PyConfig_Read(config: [*c]PyConfig) PyStatus;
pub extern fn PyConfig_SetBytesArgv(config: [*c]PyConfig, argc: Py_ssize_t, argv: [*c]const [*c]u8) PyStatus;
pub extern fn PyConfig_SetArgv(config: [*c]PyConfig, argc: Py_ssize_t, argv: [*c]const [*c]wchar_t) PyStatus;
pub extern fn PyConfig_SetWideStringList(config: [*c]PyConfig, list: [*c]PyWideStringList, length: Py_ssize_t, items: [*c][*c]wchar_t) PyStatus;
pub extern fn PyConfig_Get(name: [*c]const u8) [*c]PyObject;
pub extern fn PyConfig_GetInt(name: [*c]const u8, value: [*c]c_int) c_int;
pub extern fn PyConfig_Names() [*c]PyObject;
pub extern fn PyConfig_Set(name: [*c]const u8, value: [*c]PyObject) c_int;
pub extern fn Py_GetArgcArgv(argc: [*c]c_int, argv: [*c][*c][*c]wchar_t) void;
pub const struct_PyInitConfig = opaque {
    pub const PyInitConfig_Free = __root.PyInitConfig_Free;
    pub const PyInitConfig_GetError = __root.PyInitConfig_GetError;
    pub const PyInitConfig_GetExitCode = __root.PyInitConfig_GetExitCode;
    pub const PyInitConfig_HasOption = __root.PyInitConfig_HasOption;
    pub const PyInitConfig_GetInt = __root.PyInitConfig_GetInt;
    pub const PyInitConfig_GetStr = __root.PyInitConfig_GetStr;
    pub const PyInitConfig_GetStrList = __root.PyInitConfig_GetStrList;
    pub const PyInitConfig_SetInt = __root.PyInitConfig_SetInt;
    pub const PyInitConfig_SetStr = __root.PyInitConfig_SetStr;
    pub const PyInitConfig_SetStrList = __root.PyInitConfig_SetStrList;
    pub const PyInitConfig_AddModule = __root.PyInitConfig_AddModule;
    pub const Py_InitializeFromInitConfig = __root.Py_InitializeFromInitConfig;
    pub const Free = __root.PyInitConfig_Free;
    pub const GetError = __root.PyInitConfig_GetError;
    pub const GetExitCode = __root.PyInitConfig_GetExitCode;
    pub const HasOption = __root.PyInitConfig_HasOption;
    pub const GetInt = __root.PyInitConfig_GetInt;
    pub const GetStr = __root.PyInitConfig_GetStr;
    pub const GetStrList = __root.PyInitConfig_GetStrList;
    pub const SetInt = __root.PyInitConfig_SetInt;
    pub const SetStr = __root.PyInitConfig_SetStr;
    pub const SetStrList = __root.PyInitConfig_SetStrList;
    pub const AddModule = __root.PyInitConfig_AddModule;
    pub const InitializeFromInitConfig = __root.Py_InitializeFromInitConfig;
};
pub const PyInitConfig = struct_PyInitConfig;
pub extern fn PyInitConfig_Create() ?*PyInitConfig;
pub extern fn PyInitConfig_Free(config: ?*PyInitConfig) void;
pub extern fn PyInitConfig_GetError(config: ?*PyInitConfig, err_msg: [*c][*c]const u8) c_int;
pub extern fn PyInitConfig_GetExitCode(config: ?*PyInitConfig, exitcode: [*c]c_int) c_int;
pub extern fn PyInitConfig_HasOption(config: ?*PyInitConfig, name: [*c]const u8) c_int;
pub extern fn PyInitConfig_GetInt(config: ?*PyInitConfig, name: [*c]const u8, value: [*c]i64) c_int;
pub extern fn PyInitConfig_GetStr(config: ?*PyInitConfig, name: [*c]const u8, value: [*c][*c]u8) c_int;
pub extern fn PyInitConfig_GetStrList(config: ?*PyInitConfig, name: [*c]const u8, length: [*c]usize, items: [*c][*c][*c]u8) c_int;
pub extern fn PyInitConfig_FreeStrList(length: usize, items: [*c][*c]u8) void;
pub extern fn PyInitConfig_SetInt(config: ?*PyInitConfig, name: [*c]const u8, value: i64) c_int;
pub extern fn PyInitConfig_SetStr(config: ?*PyInitConfig, name: [*c]const u8, value: [*c]const u8) c_int;
pub extern fn PyInitConfig_SetStrList(config: ?*PyInitConfig, name: [*c]const u8, length: usize, items: [*c]const [*c]u8) c_int;
pub extern fn PyInitConfig_AddModule(config: ?*PyInitConfig, name: [*c]const u8, initfunc: ?*const fn () callconv(.c) [*c]PyObject) c_int;
pub extern fn Py_InitializeFromInitConfig(config: ?*PyInitConfig) c_int;
pub extern fn PyInterpreterState_New() ?*PyInterpreterState;
pub extern fn PyInterpreterState_Clear(?*PyInterpreterState) void;
pub extern fn PyInterpreterState_Delete(?*PyInterpreterState) void;
pub extern fn PyInterpreterState_Get() ?*PyInterpreterState;
pub extern fn PyInterpreterState_GetDict(?*PyInterpreterState) [*c]PyObject;
pub extern fn PyInterpreterState_GetID(?*PyInterpreterState) i64;
pub extern fn PyState_AddModule([*c]PyObject, [*c]PyModuleDef) c_int;
pub extern fn PyState_RemoveModule([*c]PyModuleDef) c_int;
pub extern fn PyState_FindModule([*c]PyModuleDef) [*c]PyObject;
pub extern fn PyThreadState_New(?*PyInterpreterState) ?*PyThreadState;
pub extern fn PyThreadState_Clear(?*PyThreadState) void;
pub extern fn PyThreadState_Delete(?*PyThreadState) void;
pub extern fn PyThreadState_Get() ?*PyThreadState;
pub extern fn PyThreadState_Swap(?*PyThreadState) ?*PyThreadState;
pub extern fn PyThreadState_GetDict() [*c]PyObject;
pub extern fn PyThreadState_SetAsyncExc(c_ulong, [*c]PyObject) c_int;
pub extern fn PyThreadState_GetInterpreter(tstate: ?*PyThreadState) ?*PyInterpreterState;
pub extern fn PyThreadState_GetFrame(tstate: ?*PyThreadState) ?*PyFrameObject;
pub extern fn PyThreadState_GetID(tstate: ?*PyThreadState) u64;
pub const PyGILState_LOCKED: c_int = 0;
pub const PyGILState_UNLOCKED: c_int = 1;
pub const PyGILState_STATE = c_uint;
pub extern fn PyGILState_Ensure() PyGILState_STATE;
pub extern fn PyGILState_Release(PyGILState_STATE) void;
pub extern fn PyGILState_GetThisThreadState() ?*PyThreadState;
pub extern fn _PyInterpreterState_RequiresIDRef(?*PyInterpreterState) c_int;
pub extern fn _PyInterpreterState_RequireIDRef(?*PyInterpreterState, c_int) void;
pub const Py_tracefunc = ?*const fn ([*c]PyObject, ?*PyFrameObject, c_int, [*c]PyObject) callconv(.c) c_int;
pub const _PyRemoteDebuggerSupport = extern struct {
    debugger_pending_call: i32 = 0,
    debugger_script_path: [512]u8 = @import("std").mem.zeroes([512]u8),
};
pub const struct__err_stackitem = extern struct {
    exc_value: [*c]PyObject = null,
    previous_item: [*c]struct__err_stackitem = null,
};
pub const _PyErr_StackItem = struct__err_stackitem;
pub const struct__stack_chunk = extern struct {
    previous: [*c]struct__stack_chunk = null,
    size: usize = 0,
    top: usize = 0,
    data: [1][*c]PyObject = @import("std").mem.zeroes([1][*c]PyObject),
};
pub const _PyStackChunk = struct__stack_chunk;
pub extern fn PyThreadState_GetUnchecked() ?*PyThreadState;
pub fn _PyThreadState_UncheckedGet() callconv(.c) ?*PyThreadState {
    return PyThreadState_GetUnchecked();
}
pub extern fn PyThreadState_EnterTracing(tstate: ?*PyThreadState) void;
pub extern fn PyThreadState_LeaveTracing(tstate: ?*PyThreadState) void;
pub extern fn PyGILState_Check() c_int;
pub extern fn _PyThread_CurrentFrames() [*c]PyObject;
pub extern fn PyUnstable_ThreadState_SetStackProtection(tstate: ?*PyThreadState, stack_start_addr: ?*anyopaque, stack_size: usize) c_int;
pub extern fn PyUnstable_ThreadState_ResetStackProtection(tstate: ?*PyThreadState) void;
pub extern fn PyInterpreterState_Main() ?*PyInterpreterState;
pub extern fn PyInterpreterState_Head() ?*PyInterpreterState;
pub extern fn PyInterpreterState_Next(?*PyInterpreterState) ?*PyInterpreterState;
pub extern fn PyInterpreterState_ThreadHead(?*PyInterpreterState) ?*PyThreadState;
pub extern fn PyThreadState_Next(?*PyThreadState) ?*PyThreadState;
pub extern fn PyThreadState_DeleteCurrent() void;
pub const _PyFrameEvalFunction = ?*const fn (tstate: ?*PyThreadState, ?*struct__PyInterpreterFrame, c_int) callconv(.c) [*c]PyObject;
pub extern fn _PyInterpreterState_GetEvalFrameFunc(interp: ?*PyInterpreterState) _PyFrameEvalFunction;
pub extern fn _PyInterpreterState_SetEvalFrameFunc(interp: ?*PyInterpreterState, eval_frame: _PyFrameEvalFunction) void;
pub const struct__PyGenObject = opaque {
    pub const PyGen_GetCode = __root.PyGen_GetCode;
    pub const GetCode = __root.PyGen_GetCode;
};
pub const PyGenObject = struct__PyGenObject;
pub extern var PyGen_Type: PyTypeObject;
pub extern fn PyGen_New(?*PyFrameObject) [*c]PyObject;
pub extern fn PyGen_NewWithQualName(?*PyFrameObject, name: [*c]PyObject, qualname: [*c]PyObject) [*c]PyObject;
pub extern fn PyGen_GetCode(gen: ?*PyGenObject) [*c]PyCodeObject;
pub const struct__PyCoroObject = opaque {};
pub const PyCoroObject = struct__PyCoroObject;
pub extern var PyCoro_Type: PyTypeObject;
pub extern fn PyCoro_New(?*PyFrameObject, name: [*c]PyObject, qualname: [*c]PyObject) [*c]PyObject;
pub const struct__PyAsyncGenObject = opaque {};
pub const PyAsyncGenObject = struct__PyAsyncGenObject;
pub extern var PyAsyncGen_Type: PyTypeObject;
pub extern var _PyAsyncGenASend_Type: PyTypeObject;
pub extern fn PyAsyncGen_New(?*PyFrameObject, name: [*c]PyObject, qualname: [*c]PyObject) [*c]PyObject;
pub extern var PyClassMethodDescr_Type: PyTypeObject;
pub extern var PyGetSetDescr_Type: PyTypeObject;
pub extern var PyMemberDescr_Type: PyTypeObject;
pub extern var PyMethodDescr_Type: PyTypeObject;
pub extern var PyWrapperDescr_Type: PyTypeObject;
pub extern var PyDictProxy_Type: PyTypeObject;
pub extern var PyProperty_Type: PyTypeObject;
pub extern fn PyDescr_NewMethod([*c]PyTypeObject, [*c]PyMethodDef) [*c]PyObject;
pub extern fn PyDescr_NewClassMethod([*c]PyTypeObject, [*c]PyMethodDef) [*c]PyObject;
pub extern fn PyDescr_NewMember([*c]PyTypeObject, [*c]PyMemberDef) [*c]PyObject;
pub extern fn PyDescr_NewGetSet([*c]PyTypeObject, [*c]PyGetSetDef) [*c]PyObject;
pub extern fn PyDictProxy_New([*c]PyObject) [*c]PyObject;
pub extern fn PyWrapper_New([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyMember_GetOne([*c]const u8, [*c]PyMemberDef) [*c]PyObject;
pub extern fn PyMember_SetOne([*c]u8, [*c]PyMemberDef, [*c]PyObject) c_int;
pub const wrapperfunc = ?*const fn (self: [*c]PyObject, args: [*c]PyObject, wrapped: ?*anyopaque) callconv(.c) [*c]PyObject;
pub const wrapperfunc_kwds = ?*const fn (self: [*c]PyObject, args: [*c]PyObject, wrapped: ?*anyopaque, kwds: [*c]PyObject) callconv(.c) [*c]PyObject;
pub const struct_wrapperbase = extern struct {
    name: [*c]const u8 = null,
    offset: c_int = 0,
    function: ?*anyopaque = null,
    wrapper: wrapperfunc = null,
    doc: [*c]const u8 = null,
    flags: c_int = 0,
    name_strobj: [*c]PyObject = null,
};
pub const PyDescrObject = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    d_type: [*c]PyTypeObject = null,
    d_name: [*c]PyObject = null,
    d_qualname: [*c]PyObject = null,
};
pub const PyMethodDescrObject = extern struct {
    d_common: PyDescrObject = @import("std").mem.zeroes(PyDescrObject),
    d_method: [*c]PyMethodDef = null,
    vectorcall: vectorcallfunc = null,
};
pub const PyMemberDescrObject = extern struct {
    d_common: PyDescrObject = @import("std").mem.zeroes(PyDescrObject),
    d_member: [*c]PyMemberDef = null,
};
pub const PyGetSetDescrObject = extern struct {
    d_common: PyDescrObject = @import("std").mem.zeroes(PyDescrObject),
    d_getset: [*c]PyGetSetDef = null,
};
pub const PyWrapperDescrObject = extern struct {
    d_common: PyDescrObject = @import("std").mem.zeroes(PyDescrObject),
    d_base: [*c]struct_wrapperbase = null,
    d_wrapped: ?*anyopaque = null,
};
pub extern fn PyDescr_NewWrapper([*c]PyTypeObject, [*c]struct_wrapperbase, ?*anyopaque) [*c]PyObject;
pub extern fn PyDescr_IsData([*c]PyObject) c_int;
pub extern fn Py_GenericAlias([*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern var Py_GenericAliasType: PyTypeObject;
pub extern fn PyErr_WarnEx(category: [*c]PyObject, message: [*c]const u8, stack_level: Py_ssize_t) c_int;
pub extern fn PyErr_WarnFormat(category: [*c]PyObject, stack_level: Py_ssize_t, format: [*c]const u8, ...) c_int;
pub extern fn PyErr_ResourceWarning(source: [*c]PyObject, stack_level: Py_ssize_t, format: [*c]const u8, ...) c_int;
pub extern fn PyErr_WarnExplicit(category: [*c]PyObject, message: [*c]const u8, filename: [*c]const u8, lineno: c_int, module: [*c]const u8, registry: [*c]PyObject) c_int;
pub extern fn PyErr_WarnExplicitObject(category: [*c]PyObject, message: [*c]PyObject, filename: [*c]PyObject, lineno: c_int, module: [*c]PyObject, registry: [*c]PyObject) c_int;
pub extern fn PyErr_WarnExplicitFormat(category: [*c]PyObject, filename: [*c]const u8, lineno: c_int, module: [*c]const u8, registry: [*c]PyObject, format: [*c]const u8, ...) c_int;
pub const PyWeakReference = struct__PyWeakReference;
pub const struct__PyWeakReference = extern struct {
    ob_base: PyObject = @import("std").mem.zeroes(PyObject),
    wr_object: [*c]PyObject = null,
    wr_callback: [*c]PyObject = null,
    hash: Py_hash_t = 0,
    wr_prev: [*c]PyWeakReference = null,
    wr_next: [*c]PyWeakReference = null,
    vectorcall: vectorcallfunc = null,
    pub const _PyWeakref_ClearRef = __root._PyWeakref_ClearRef;
    pub const ClearRef = __root._PyWeakref_ClearRef;
};
pub extern var _PyWeakref_RefType: PyTypeObject;
pub extern var _PyWeakref_ProxyType: PyTypeObject;
pub extern var _PyWeakref_CallableProxyType: PyTypeObject;
pub extern fn PyWeakref_NewRef(ob: [*c]PyObject, callback: [*c]PyObject) [*c]PyObject;
pub extern fn PyWeakref_NewProxy(ob: [*c]PyObject, callback: [*c]PyObject) [*c]PyObject;
pub extern fn PyWeakref_GetObject(ref: [*c]PyObject) [*c]PyObject;
pub extern fn PyWeakref_GetRef(ref: [*c]PyObject, pobj: [*c][*c]PyObject) c_int;
pub extern fn _PyWeakref_ClearRef(self: [*c]PyWeakReference) void;
pub extern fn PyWeakref_IsDead(ref: [*c]PyObject) c_int;
pub fn PyWeakref_GET_OBJECT(arg_ref_obj: [*c]PyObject) callconv(.c) [*c]PyObject {
    var ref_obj = arg_ref_obj;
    _ = &ref_obj;
    var ref: [*c]PyWeakReference = blk: {
        _ = @as(c_int, 0);
        break :blk @as([*c]PyWeakReference, @ptrCast(@alignCast(ref_obj)));
    };
    _ = &ref;
    var obj: [*c]PyObject = ref.*.wr_object;
    _ = &obj;
    if (_Py_REFCNT(obj) > @as(Py_ssize_t, 0)) {
        return obj;
    }
    return &_Py_NoneStruct;
}
pub const struct_PyStructSequence_Field = extern struct {
    name: [*c]const u8 = null,
    doc: [*c]const u8 = null,
};
pub const PyStructSequence_Field = struct_PyStructSequence_Field;
pub const struct_PyStructSequence_Desc = extern struct {
    name: [*c]const u8 = null,
    doc: [*c]const u8 = null,
    fields: [*c]PyStructSequence_Field = null,
    n_in_sequence: c_int = 0,
    pub const PyStructSequence_NewType = __root.PyStructSequence_NewType;
    pub const NewType = __root.PyStructSequence_NewType;
};
pub const PyStructSequence_Desc = struct_PyStructSequence_Desc;
pub extern const PyStructSequence_UnnamedField: [*c]const u8;
pub extern fn PyStructSequence_InitType(@"type": [*c]PyTypeObject, desc: [*c]PyStructSequence_Desc) void;
pub extern fn PyStructSequence_InitType2(@"type": [*c]PyTypeObject, desc: [*c]PyStructSequence_Desc) c_int;
pub extern fn PyStructSequence_NewType(desc: [*c]PyStructSequence_Desc) [*c]PyTypeObject;
pub extern fn PyStructSequence_New(@"type": [*c]PyTypeObject) [*c]PyObject;
pub extern fn PyStructSequence_SetItem([*c]PyObject, Py_ssize_t, [*c]PyObject) void;
pub extern fn PyStructSequence_GetItem([*c]PyObject, Py_ssize_t) [*c]PyObject;
pub const PyStructSequence = PyTupleObject;
pub extern var PyPickleBuffer_Type: PyTypeObject;
pub extern fn PyPickleBuffer_FromObject([*c]PyObject) [*c]PyObject;
pub extern fn PyPickleBuffer_GetBuffer([*c]PyObject) [*c]const Py_buffer;
pub extern fn PyPickleBuffer_Release([*c]PyObject) c_int;
pub const PyTime_t = i64;
pub extern fn PyTime_AsSecondsDouble(t: PyTime_t) f64;
pub extern fn PyTime_Monotonic(result: [*c]PyTime_t) c_int;
pub extern fn PyTime_PerfCounter(result: [*c]PyTime_t) c_int;
pub extern fn PyTime_Time(result: [*c]PyTime_t) c_int;
pub extern fn PyTime_MonotonicRaw(result: [*c]PyTime_t) c_int;
pub extern fn PyTime_PerfCounterRaw(result: [*c]PyTime_t) c_int;
pub extern fn PyTime_TimeRaw(result: [*c]PyTime_t) c_int;
pub extern fn PyCodec_Register(search_function: [*c]PyObject) c_int;
pub extern fn PyCodec_Unregister(search_function: [*c]PyObject) c_int;
pub extern fn PyCodec_KnownEncoding(encoding: [*c]const u8) c_int;
pub extern fn PyCodec_Encode(object: [*c]PyObject, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_Decode(object: [*c]PyObject, encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_Encoder(encoding: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_Decoder(encoding: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_IncrementalEncoder(encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_IncrementalDecoder(encoding: [*c]const u8, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_StreamReader(encoding: [*c]const u8, stream: [*c]PyObject, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_StreamWriter(encoding: [*c]const u8, stream: [*c]PyObject, errors: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_RegisterError(name: [*c]const u8, @"error": [*c]PyObject) c_int;
pub extern fn PyCodec_LookupError(name: [*c]const u8) [*c]PyObject;
pub extern fn PyCodec_StrictErrors(exc: [*c]PyObject) [*c]PyObject;
pub extern fn PyCodec_IgnoreErrors(exc: [*c]PyObject) [*c]PyObject;
pub extern fn PyCodec_ReplaceErrors(exc: [*c]PyObject) [*c]PyObject;
pub extern fn PyCodec_XMLCharRefReplaceErrors(exc: [*c]PyObject) [*c]PyObject;
pub extern fn PyCodec_BackslashReplaceErrors(exc: [*c]PyObject) [*c]PyObject;
pub extern fn PyCodec_NameReplaceErrors(exc: [*c]PyObject) [*c]PyObject;
pub extern var Py_hexdigits: [*c]const u8;
pub const PyThread_type_lock = ?*anyopaque;
pub const PY_LOCK_FAILURE: c_int = 0;
pub const PY_LOCK_ACQUIRED: c_int = 1;
pub const PY_LOCK_INTR: c_int = 2;
pub const enum_PyLockStatus = c_uint;
pub const PyLockStatus = enum_PyLockStatus;
pub extern fn PyThread_init_thread() void;
pub extern fn PyThread_start_new_thread(?*const fn (?*anyopaque) callconv(.c) void, ?*anyopaque) c_ulong;
pub extern fn PyThread_exit_thread() noreturn;
pub extern fn PyThread_get_thread_ident() c_ulong;
pub extern fn PyThread_get_thread_native_id() c_ulong;
pub extern fn PyThread_allocate_lock() PyThread_type_lock;
pub extern fn PyThread_free_lock(PyThread_type_lock) void;
pub extern fn PyThread_acquire_lock(PyThread_type_lock, c_int) c_int;
pub extern fn PyThread_acquire_lock_timed(PyThread_type_lock, microseconds: c_longlong, intr_flag: c_int) PyLockStatus;
pub extern fn PyThread_release_lock(PyThread_type_lock) void;
pub extern fn PyThread_get_stacksize() usize;
pub extern fn PyThread_set_stacksize(usize) c_int;
pub extern fn PyThread_GetInfo() [*c]PyObject;
pub extern fn PyThread_create_key() c_int;
pub extern fn PyThread_delete_key(key: c_int) void;
pub extern fn PyThread_set_key_value(key: c_int, value: ?*anyopaque) c_int;
pub extern fn PyThread_get_key_value(key: c_int) ?*anyopaque;
pub extern fn PyThread_delete_key_value(key: c_int) void;
pub extern fn PyThread_ReInitTLS() void;
pub const struct__Py_tss_t = extern struct {
    _is_initialized: c_int = 0,
    _key: pthread_key_t = 0,
    pub const PyThread_tss_free = __root.PyThread_tss_free;
    pub const PyThread_tss_is_created = __root.PyThread_tss_is_created;
    pub const PyThread_tss_create = __root.PyThread_tss_create;
    pub const PyThread_tss_delete = __root.PyThread_tss_delete;
    pub const PyThread_tss_set = __root.PyThread_tss_set;
    pub const PyThread_tss_get = __root.PyThread_tss_get;
    pub const created = __root.PyThread_tss_is_created;
    pub const create = __root.PyThread_tss_create;
    pub const delete = __root.PyThread_tss_delete;
    pub const set = __root.PyThread_tss_set;
    pub const get = __root.PyThread_tss_get;
};
pub const Py_tss_t = struct__Py_tss_t;
pub extern fn PyThread_tss_alloc() [*c]Py_tss_t;
pub extern fn PyThread_tss_free(key: [*c]Py_tss_t) void;
pub extern fn PyThread_tss_is_created(key: [*c]Py_tss_t) c_int;
pub extern fn PyThread_tss_create(key: [*c]Py_tss_t) c_int;
pub extern fn PyThread_tss_delete(key: [*c]Py_tss_t) void;
pub extern fn PyThread_tss_set(key: [*c]Py_tss_t, value: ?*anyopaque) c_int;
pub extern fn PyThread_tss_get(key: [*c]Py_tss_t) ?*anyopaque;
pub extern const PY_TIMEOUT_MAX: c_longlong;
pub const struct_sched_param = extern struct {
    sched_priority: c_int = 0,
};
pub extern fn clone(__fn: ?*const fn (__arg: ?*anyopaque) callconv(.c) c_int, __child_stack: ?*anyopaque, __flags: c_int, __arg: ?*anyopaque, ...) c_int;
pub extern fn unshare(__flags: c_int) c_int;
pub extern fn sched_getcpu() c_int;
pub extern fn getcpu([*c]c_uint, [*c]c_uint) c_int;
pub extern fn setns(__fd: c_int, __nstype: c_int) c_int;
pub const __cpu_mask = c_ulong;
pub const cpu_set_t = extern struct {
    __bits: [16]__cpu_mask = @import("std").mem.zeroes([16]__cpu_mask),
    pub const __sched_cpufree = __root.__sched_cpufree;
    pub const cpufree = __root.__sched_cpufree;
};
pub extern fn __sched_cpucount(__setsize: usize, __setp: [*c]const cpu_set_t) c_int;
pub extern fn __sched_cpualloc(__count: usize) [*c]cpu_set_t;
pub extern fn __sched_cpufree(__set: [*c]cpu_set_t) void;
pub extern fn sched_setparam(__pid: __pid_t, __param: [*c]const struct_sched_param) c_int;
pub extern fn sched_getparam(__pid: __pid_t, __param: [*c]struct_sched_param) c_int;
pub extern fn sched_setscheduler(__pid: __pid_t, __policy: c_int, __param: [*c]const struct_sched_param) c_int;
pub extern fn sched_getscheduler(__pid: __pid_t) c_int;
pub extern fn sched_yield() c_int;
pub extern fn sched_get_priority_max(__algorithm: c_int) c_int;
pub extern fn sched_get_priority_min(__algorithm: c_int) c_int;
pub extern fn sched_rr_get_interval(__pid: __pid_t, __t: [*c]struct_timespec) c_int;
pub extern fn sched_setaffinity(__pid: __pid_t, __cpusetsize: usize, __cpuset: [*c]const cpu_set_t) c_int;
pub extern fn sched_getaffinity(__pid: __pid_t, __cpusetsize: usize, __cpuset: [*c]cpu_set_t) c_int; // /home/fnn45/zig-x86_64-linux-0.16.0/lib/compiler/aro/include/stdint.h:3:2: warning: struct demoted to opaque type - has bitfield
pub const struct_timex = opaque {};
pub extern fn clock_adjtime(__clock_id: __clockid_t, __utx: ?*struct_timex) c_int;
pub const struct_itimerspec = extern struct {
    it_interval: struct_timespec = @import("std").mem.zeroes(struct_timespec),
    it_value: struct_timespec = @import("std").mem.zeroes(struct_timespec),
};
pub const struct_sigevent = opaque {};
pub extern fn clock() clock_t;
pub extern fn time(__timer: [*c]time_t) time_t;
pub extern fn difftime(__time1: time_t, __time0: time_t) f64;
pub extern fn mktime(__tp: [*c]struct_tm) time_t;
pub extern fn strftime(noalias __s: [*c]u8, __maxsize: usize, noalias __format: [*c]const u8, noalias __tp: [*c]const struct_tm) usize;
pub extern fn strptime(noalias __s: [*c]const u8, noalias __fmt: [*c]const u8, __tp: [*c]struct_tm) [*c]u8;
pub extern fn strftime_l(noalias __s: [*c]u8, __maxsize: usize, noalias __format: [*c]const u8, noalias __tp: [*c]const struct_tm, __loc: locale_t) usize;
pub extern fn strptime_l(noalias __s: [*c]const u8, noalias __fmt: [*c]const u8, __tp: [*c]struct_tm, __loc: locale_t) [*c]u8;
pub extern fn gmtime(__timer: [*c]const time_t) [*c]struct_tm;
pub extern fn localtime(__timer: [*c]const time_t) [*c]struct_tm;
pub extern fn gmtime_r(noalias __timer: [*c]const time_t, noalias __tp: [*c]struct_tm) [*c]struct_tm;
pub extern fn localtime_r(noalias __timer: [*c]const time_t, noalias __tp: [*c]struct_tm) [*c]struct_tm;
pub extern fn asctime(__tp: [*c]const struct_tm) [*c]u8;
pub extern fn ctime(__timer: [*c]const time_t) [*c]u8;
pub extern fn asctime_r(noalias __tp: [*c]const struct_tm, noalias __buf: [*c]u8) [*c]u8;
pub extern fn ctime_r(noalias __timer: [*c]const time_t, noalias __buf: [*c]u8) [*c]u8;
pub extern var __tzname: [2][*c]u8;
pub extern var __daylight: c_int;
pub extern var __timezone: c_long;
pub extern var tzname: [2][*c]u8;
pub extern fn tzset() void;
pub extern var daylight: c_int;
pub extern var timezone: c_long;
pub extern fn timegm(__tp: [*c]struct_tm) time_t;
pub extern fn timelocal(__tp: [*c]struct_tm) time_t;
pub extern fn dysize(__year: c_int) c_int;
pub extern fn nanosleep(__requested_time: [*c]const struct_timespec, __remaining: [*c]struct_timespec) c_int;
pub extern fn clock_getres(__clock_id: clockid_t, __res: [*c]struct_timespec) c_int;
pub extern fn clock_gettime(__clock_id: clockid_t, __tp: [*c]struct_timespec) c_int;
pub extern fn clock_settime(__clock_id: clockid_t, __tp: [*c]const struct_timespec) c_int;
pub extern fn clock_nanosleep(__clock_id: clockid_t, __flags: c_int, __req: [*c]const struct_timespec, __rem: [*c]struct_timespec) c_int;
pub extern fn clock_getcpuclockid(__pid: pid_t, __clock_id: [*c]clockid_t) c_int;
pub extern fn timer_create(__clock_id: clockid_t, noalias __evp: ?*struct_sigevent, noalias __timerid: [*c]timer_t) c_int;
pub extern fn timer_delete(__timerid: timer_t) c_int;
pub extern fn timer_settime(__timerid: timer_t, __flags: c_int, noalias __value: [*c]const struct_itimerspec, noalias __ovalue: [*c]struct_itimerspec) c_int;
pub extern fn timer_gettime(__timerid: timer_t, __value: [*c]struct_itimerspec) c_int;
pub extern fn timer_getoverrun(__timerid: timer_t) c_int;
pub extern fn timespec_get(__ts: [*c]struct_timespec, __base: c_int) c_int;
pub extern fn timespec_getres(__ts: [*c]struct_timespec, __base: c_int) c_int;
pub extern var getdate_err: c_int;
pub extern fn getdate(__string: [*c]const u8) [*c]struct_tm;
pub extern fn getdate_r(noalias __string: [*c]const u8, noalias __resbufp: [*c]struct_tm) c_int;
pub const __jmp_buf = [8]c_long;
pub const struct___jmp_buf_tag = extern struct {
    __jmpbuf: __jmp_buf = @import("std").mem.zeroes(__jmp_buf),
    __mask_was_saved: c_int = 0,
    __saved_mask: __sigset_t = @import("std").mem.zeroes(__sigset_t),
    pub const __sigsetjmp = __root.__sigsetjmp;
    pub const sigsetjmp = __root.__sigsetjmp;
};
pub const PTHREAD_CREATE_JOINABLE: c_int = 0;
pub const PTHREAD_CREATE_DETACHED: c_int = 1;
const enum_unnamed_20 = c_uint;
pub const PTHREAD_MUTEX_TIMED_NP: c_int = 0;
pub const PTHREAD_MUTEX_RECURSIVE_NP: c_int = 1;
pub const PTHREAD_MUTEX_ERRORCHECK_NP: c_int = 2;
pub const PTHREAD_MUTEX_ADAPTIVE_NP: c_int = 3;
pub const PTHREAD_MUTEX_NORMAL: c_int = 0;
pub const PTHREAD_MUTEX_RECURSIVE: c_int = 1;
pub const PTHREAD_MUTEX_ERRORCHECK: c_int = 2;
pub const PTHREAD_MUTEX_DEFAULT: c_int = 0;
pub const PTHREAD_MUTEX_FAST_NP: c_int = 0;
const enum_unnamed_21 = c_uint;
pub const PTHREAD_MUTEX_STALLED: c_int = 0;
pub const PTHREAD_MUTEX_STALLED_NP: c_int = 0;
pub const PTHREAD_MUTEX_ROBUST: c_int = 1;
pub const PTHREAD_MUTEX_ROBUST_NP: c_int = 1;
const enum_unnamed_22 = c_uint;
pub const PTHREAD_PRIO_NONE: c_int = 0;
pub const PTHREAD_PRIO_INHERIT: c_int = 1;
pub const PTHREAD_PRIO_PROTECT: c_int = 2;
const enum_unnamed_23 = c_uint;
pub const PTHREAD_RWLOCK_PREFER_READER_NP: c_int = 0;
pub const PTHREAD_RWLOCK_PREFER_WRITER_NP: c_int = 1;
pub const PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP: c_int = 2;
pub const PTHREAD_RWLOCK_DEFAULT_NP: c_int = 0;
const enum_unnamed_24 = c_uint;
pub const PTHREAD_INHERIT_SCHED: c_int = 0;
pub const PTHREAD_EXPLICIT_SCHED: c_int = 1;
const enum_unnamed_25 = c_uint;
pub const PTHREAD_SCOPE_SYSTEM: c_int = 0;
pub const PTHREAD_SCOPE_PROCESS: c_int = 1;
const enum_unnamed_26 = c_uint;
pub const PTHREAD_PROCESS_PRIVATE: c_int = 0;
pub const PTHREAD_PROCESS_SHARED: c_int = 1;
const enum_unnamed_27 = c_uint;
pub const struct__pthread_cleanup_buffer = extern struct {
    __routine: ?*const fn (?*anyopaque) callconv(.c) void = null,
    __arg: ?*anyopaque = null,
    __canceltype: c_int = 0,
    __prev: [*c]struct__pthread_cleanup_buffer = null,
};
pub const PTHREAD_CANCEL_ENABLE: c_int = 0;
pub const PTHREAD_CANCEL_DISABLE: c_int = 1;
const enum_unnamed_28 = c_uint;
pub const PTHREAD_CANCEL_DEFERRED: c_int = 0;
pub const PTHREAD_CANCEL_ASYNCHRONOUS: c_int = 1;
const enum_unnamed_29 = c_uint;
pub extern fn pthread_create(noalias __newthread: [*c]pthread_t, noalias __attr: [*c]const pthread_attr_t, __start_routine: ?*const fn (?*anyopaque) callconv(.c) ?*anyopaque, noalias __arg: ?*anyopaque) c_int;
pub extern fn pthread_exit(__retval: ?*anyopaque) noreturn;
pub extern fn pthread_join(__th: pthread_t, __thread_return: [*c]?*anyopaque) c_int;
pub extern fn pthread_tryjoin_np(__th: pthread_t, __thread_return: [*c]?*anyopaque) c_int;
pub extern fn pthread_timedjoin_np(__th: pthread_t, __thread_return: [*c]?*anyopaque, __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_clockjoin_np(__th: pthread_t, __thread_return: [*c]?*anyopaque, __clockid: clockid_t, __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_detach(__th: pthread_t) c_int;
pub extern fn pthread_self() pthread_t;
pub fn pthread_equal(arg___thread1: pthread_t, arg___thread2: pthread_t) callconv(.c) c_int {
    var __thread1 = arg___thread1;
    _ = &__thread1;
    var __thread2 = arg___thread2;
    _ = &__thread2;
    return @intFromBool(__thread1 == __thread2);
}
pub extern fn pthread_attr_init(__attr: [*c]pthread_attr_t) c_int;
pub extern fn pthread_attr_destroy(__attr: [*c]pthread_attr_t) c_int;
pub extern fn pthread_attr_getdetachstate(__attr: [*c]const pthread_attr_t, __detachstate: [*c]c_int) c_int;
pub extern fn pthread_attr_setdetachstate(__attr: [*c]pthread_attr_t, __detachstate: c_int) c_int;
pub extern fn pthread_attr_getguardsize(__attr: [*c]const pthread_attr_t, __guardsize: [*c]usize) c_int;
pub extern fn pthread_attr_setguardsize(__attr: [*c]pthread_attr_t, __guardsize: usize) c_int;
pub extern fn pthread_attr_getschedparam(noalias __attr: [*c]const pthread_attr_t, noalias __param: [*c]struct_sched_param) c_int;
pub extern fn pthread_attr_setschedparam(noalias __attr: [*c]pthread_attr_t, noalias __param: [*c]const struct_sched_param) c_int;
pub extern fn pthread_attr_getschedpolicy(noalias __attr: [*c]const pthread_attr_t, noalias __policy: [*c]c_int) c_int;
pub extern fn pthread_attr_setschedpolicy(__attr: [*c]pthread_attr_t, __policy: c_int) c_int;
pub extern fn pthread_attr_getinheritsched(noalias __attr: [*c]const pthread_attr_t, noalias __inherit: [*c]c_int) c_int;
pub extern fn pthread_attr_setinheritsched(__attr: [*c]pthread_attr_t, __inherit: c_int) c_int;
pub extern fn pthread_attr_getscope(noalias __attr: [*c]const pthread_attr_t, noalias __scope: [*c]c_int) c_int;
pub extern fn pthread_attr_setscope(__attr: [*c]pthread_attr_t, __scope: c_int) c_int;
pub extern fn pthread_attr_getstackaddr(noalias __attr: [*c]const pthread_attr_t, noalias __stackaddr: [*c]?*anyopaque) c_int;
pub extern fn pthread_attr_setstackaddr(__attr: [*c]pthread_attr_t, __stackaddr: ?*anyopaque) c_int;
pub extern fn pthread_attr_getstacksize(noalias __attr: [*c]const pthread_attr_t, noalias __stacksize: [*c]usize) c_int;
pub extern fn pthread_attr_setstacksize(__attr: [*c]pthread_attr_t, __stacksize: usize) c_int;
pub extern fn pthread_attr_getstack(noalias __attr: [*c]const pthread_attr_t, noalias __stackaddr: [*c]?*anyopaque, noalias __stacksize: [*c]usize) c_int;
pub extern fn pthread_attr_setstack(__attr: [*c]pthread_attr_t, __stackaddr: ?*anyopaque, __stacksize: usize) c_int;
pub extern fn pthread_attr_setaffinity_np(__attr: [*c]pthread_attr_t, __cpusetsize: usize, __cpuset: [*c]const cpu_set_t) c_int;
pub extern fn pthread_attr_getaffinity_np(__attr: [*c]const pthread_attr_t, __cpusetsize: usize, __cpuset: [*c]cpu_set_t) c_int;
pub extern fn pthread_getattr_default_np(__attr: [*c]pthread_attr_t) c_int;
pub extern fn pthread_attr_setsigmask_np(__attr: [*c]pthread_attr_t, sigmask: [*c]const __sigset_t) c_int;
pub extern fn pthread_attr_getsigmask_np(__attr: [*c]const pthread_attr_t, sigmask: [*c]__sigset_t) c_int;
pub extern fn pthread_setattr_default_np(__attr: [*c]const pthread_attr_t) c_int;
pub extern fn pthread_getattr_np(__th: pthread_t, __attr: [*c]pthread_attr_t) c_int;
pub extern fn pthread_setschedparam(__target_thread: pthread_t, __policy: c_int, __param: [*c]const struct_sched_param) c_int;
pub extern fn pthread_getschedparam(__target_thread: pthread_t, noalias __policy: [*c]c_int, noalias __param: [*c]struct_sched_param) c_int;
pub extern fn pthread_setschedprio(__target_thread: pthread_t, __prio: c_int) c_int;
pub extern fn pthread_getname_np(__target_thread: pthread_t, __buf: [*c]u8, __buflen: usize) c_int;
pub extern fn pthread_setname_np(__target_thread: pthread_t, __name: [*c]const u8) c_int;
pub extern fn pthread_getconcurrency() c_int;
pub extern fn pthread_setconcurrency(__level: c_int) c_int;
pub extern fn pthread_yield() c_int;
pub extern fn pthread_setaffinity_np(__th: pthread_t, __cpusetsize: usize, __cpuset: [*c]const cpu_set_t) c_int;
pub extern fn pthread_getaffinity_np(__th: pthread_t, __cpusetsize: usize, __cpuset: [*c]cpu_set_t) c_int;
pub extern fn pthread_once(__once_control: [*c]pthread_once_t, __init_routine: ?*const fn () callconv(.c) void) c_int;
pub extern fn pthread_setcancelstate(__state: c_int, __oldstate: [*c]c_int) c_int;
pub extern fn pthread_setcanceltype(__type: c_int, __oldtype: [*c]c_int) c_int;
pub extern fn pthread_cancel(__th: pthread_t) c_int;
pub extern fn pthread_testcancel() void;
pub const struct___cancel_jmp_buf_tag = extern struct {
    __cancel_jmp_buf: __jmp_buf = @import("std").mem.zeroes(__jmp_buf),
    __mask_was_saved: c_int = 0,
};
pub const __pthread_unwind_buf_t = extern struct {
    __cancel_jmp_buf: [1]struct___cancel_jmp_buf_tag = @import("std").mem.zeroes([1]struct___cancel_jmp_buf_tag),
    __pad: [4]?*anyopaque = @import("std").mem.zeroes([4]?*anyopaque),
    pub const __pthread_register_cancel = __root.__pthread_register_cancel;
    pub const __pthread_unregister_cancel = __root.__pthread_unregister_cancel;
    pub const __pthread_register_cancel_defer = __root.__pthread_register_cancel_defer;
    pub const __pthread_unregister_cancel_restore = __root.__pthread_unregister_cancel_restore;
    pub const __pthread_unwind_next = __root.__pthread_unwind_next;
    pub const cancel = __root.__pthread_register_cancel;
    pub const @"defer" = __root.__pthread_register_cancel_defer;
    pub const restore = __root.__pthread_unregister_cancel_restore;
    pub const next = __root.__pthread_unwind_next;
};
pub const struct___pthread_cleanup_frame = extern struct {
    __cancel_routine: ?*const fn (?*anyopaque) callconv(.c) void = null,
    __cancel_arg: ?*anyopaque = null,
    __do_it: c_int = 0,
    __cancel_type: c_int = 0,
};
pub extern fn __pthread_register_cancel(__buf: [*c]__pthread_unwind_buf_t) void;
pub extern fn __pthread_unregister_cancel(__buf: [*c]__pthread_unwind_buf_t) void;
pub extern fn __pthread_register_cancel_defer(__buf: [*c]__pthread_unwind_buf_t) void;
pub extern fn __pthread_unregister_cancel_restore(__buf: [*c]__pthread_unwind_buf_t) void; // /usr/include/pthread.h:750:13: warning: TODO weak linkage ignored
pub extern fn __pthread_unwind_next(__buf: [*c]__pthread_unwind_buf_t) noreturn;
pub extern fn __sigsetjmp(__env: [*c]struct___jmp_buf_tag, __savemask: c_int) c_int;
pub extern fn pthread_mutex_init(__mutex: [*c]pthread_mutex_t, __mutexattr: [*c]const pthread_mutexattr_t) c_int;
pub extern fn pthread_mutex_destroy(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_trylock(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_lock(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_timedlock(noalias __mutex: [*c]pthread_mutex_t, noalias __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_mutex_clocklock(noalias __mutex: [*c]pthread_mutex_t, __clockid: clockid_t, noalias __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_mutex_unlock(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_getprioceiling(noalias __mutex: [*c]const pthread_mutex_t, noalias __prioceiling: [*c]c_int) c_int;
pub extern fn pthread_mutex_setprioceiling(noalias __mutex: [*c]pthread_mutex_t, __prioceiling: c_int, noalias __old_ceiling: [*c]c_int) c_int;
pub extern fn pthread_mutex_consistent(__mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutex_consistent_np([*c]pthread_mutex_t) c_int;
pub extern fn pthread_mutexattr_init(__attr: [*c]pthread_mutexattr_t) c_int;
pub extern fn pthread_mutexattr_destroy(__attr: [*c]pthread_mutexattr_t) c_int;
pub extern fn pthread_mutexattr_getpshared(noalias __attr: [*c]const pthread_mutexattr_t, noalias __pshared: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_setpshared(__attr: [*c]pthread_mutexattr_t, __pshared: c_int) c_int;
pub extern fn pthread_mutexattr_gettype(noalias __attr: [*c]const pthread_mutexattr_t, noalias __kind: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_settype(__attr: [*c]pthread_mutexattr_t, __kind: c_int) c_int;
pub extern fn pthread_mutexattr_getprotocol(noalias __attr: [*c]const pthread_mutexattr_t, noalias __protocol: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_setprotocol(__attr: [*c]pthread_mutexattr_t, __protocol: c_int) c_int;
pub extern fn pthread_mutexattr_getprioceiling(noalias __attr: [*c]const pthread_mutexattr_t, noalias __prioceiling: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_setprioceiling(__attr: [*c]pthread_mutexattr_t, __prioceiling: c_int) c_int;
pub extern fn pthread_mutexattr_getrobust(__attr: [*c]const pthread_mutexattr_t, __robustness: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_getrobust_np([*c]pthread_mutexattr_t, [*c]c_int) c_int;
pub extern fn pthread_mutexattr_setrobust(__attr: [*c]pthread_mutexattr_t, __robustness: c_int) c_int;
pub extern fn pthread_mutexattr_setrobust_np([*c]pthread_mutexattr_t, c_int) c_int;
pub extern fn pthread_rwlock_init(noalias __rwlock: [*c]pthread_rwlock_t, noalias __attr: [*c]const pthread_rwlockattr_t) c_int;
pub extern fn pthread_rwlock_destroy(__rwlock: [*c]pthread_rwlock_t) c_int;
pub extern fn pthread_rwlock_rdlock(__rwlock: [*c]pthread_rwlock_t) c_int;
pub extern fn pthread_rwlock_tryrdlock(__rwlock: [*c]pthread_rwlock_t) c_int;
pub extern fn pthread_rwlock_timedrdlock(noalias __rwlock: [*c]pthread_rwlock_t, noalias __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_rwlock_clockrdlock(noalias __rwlock: [*c]pthread_rwlock_t, __clockid: clockid_t, noalias __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_rwlock_wrlock(__rwlock: [*c]pthread_rwlock_t) c_int;
pub extern fn pthread_rwlock_trywrlock(__rwlock: [*c]pthread_rwlock_t) c_int;
pub extern fn pthread_rwlock_timedwrlock(noalias __rwlock: [*c]pthread_rwlock_t, noalias __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_rwlock_clockwrlock(noalias __rwlock: [*c]pthread_rwlock_t, __clockid: clockid_t, noalias __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_rwlock_unlock(__rwlock: [*c]pthread_rwlock_t) c_int;
pub extern fn pthread_rwlockattr_init(__attr: [*c]pthread_rwlockattr_t) c_int;
pub extern fn pthread_rwlockattr_destroy(__attr: [*c]pthread_rwlockattr_t) c_int;
pub extern fn pthread_rwlockattr_getpshared(noalias __attr: [*c]const pthread_rwlockattr_t, noalias __pshared: [*c]c_int) c_int;
pub extern fn pthread_rwlockattr_setpshared(__attr: [*c]pthread_rwlockattr_t, __pshared: c_int) c_int;
pub extern fn pthread_rwlockattr_getkind_np(noalias __attr: [*c]const pthread_rwlockattr_t, noalias __pref: [*c]c_int) c_int;
pub extern fn pthread_rwlockattr_setkind_np(__attr: [*c]pthread_rwlockattr_t, __pref: c_int) c_int;
pub extern fn pthread_cond_init(noalias __cond: [*c]pthread_cond_t, noalias __cond_attr: [*c]const pthread_condattr_t) c_int;
pub extern fn pthread_cond_destroy(__cond: [*c]pthread_cond_t) c_int;
pub extern fn pthread_cond_signal(__cond: [*c]pthread_cond_t) c_int;
pub extern fn pthread_cond_broadcast(__cond: [*c]pthread_cond_t) c_int;
pub extern fn pthread_cond_wait(noalias __cond: [*c]pthread_cond_t, noalias __mutex: [*c]pthread_mutex_t) c_int;
pub extern fn pthread_cond_timedwait(noalias __cond: [*c]pthread_cond_t, noalias __mutex: [*c]pthread_mutex_t, noalias __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_cond_clockwait(noalias __cond: [*c]pthread_cond_t, noalias __mutex: [*c]pthread_mutex_t, __clock_id: __clockid_t, noalias __abstime: [*c]const struct_timespec) c_int;
pub extern fn pthread_condattr_init(__attr: [*c]pthread_condattr_t) c_int;
pub extern fn pthread_condattr_destroy(__attr: [*c]pthread_condattr_t) c_int;
pub extern fn pthread_condattr_getpshared(noalias __attr: [*c]const pthread_condattr_t, noalias __pshared: [*c]c_int) c_int;
pub extern fn pthread_condattr_setpshared(__attr: [*c]pthread_condattr_t, __pshared: c_int) c_int;
pub extern fn pthread_condattr_getclock(noalias __attr: [*c]const pthread_condattr_t, noalias __clock_id: [*c]__clockid_t) c_int;
pub extern fn pthread_condattr_setclock(__attr: [*c]pthread_condattr_t, __clock_id: __clockid_t) c_int;
pub extern fn pthread_spin_init(__lock: [*c]volatile pthread_spinlock_t, __pshared: c_int) c_int;
pub extern fn pthread_spin_destroy(__lock: [*c]volatile pthread_spinlock_t) c_int;
pub extern fn pthread_spin_lock(__lock: [*c]volatile pthread_spinlock_t) c_int;
pub extern fn pthread_spin_trylock(__lock: [*c]volatile pthread_spinlock_t) c_int;
pub extern fn pthread_spin_unlock(__lock: [*c]volatile pthread_spinlock_t) c_int;
pub extern fn pthread_barrier_init(noalias __barrier: [*c]pthread_barrier_t, noalias __attr: [*c]const pthread_barrierattr_t, __count: c_uint) c_int;
pub extern fn pthread_barrier_destroy(__barrier: [*c]pthread_barrier_t) c_int;
pub extern fn pthread_barrier_wait(__barrier: [*c]pthread_barrier_t) c_int;
pub extern fn pthread_barrierattr_init(__attr: [*c]pthread_barrierattr_t) c_int;
pub extern fn pthread_barrierattr_destroy(__attr: [*c]pthread_barrierattr_t) c_int;
pub extern fn pthread_barrierattr_getpshared(noalias __attr: [*c]const pthread_barrierattr_t, noalias __pshared: [*c]c_int) c_int;
pub extern fn pthread_barrierattr_setpshared(__attr: [*c]pthread_barrierattr_t, __pshared: c_int) c_int;
pub extern fn pthread_key_create(__key: [*c]pthread_key_t, __destr_function: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
pub extern fn pthread_key_delete(__key: pthread_key_t) c_int;
pub extern fn pthread_getspecific(__key: pthread_key_t) ?*anyopaque;
pub extern fn pthread_setspecific(__key: pthread_key_t, __pointer: ?*const anyopaque) c_int;
pub extern fn pthread_getcpuclockid(__thread_id: pthread_t, __clock_id: [*c]__clockid_t) c_int;
pub extern fn pthread_atfork(__prepare: ?*const fn () callconv(.c) void, __parent: ?*const fn () callconv(.c) void, __child: ?*const fn () callconv(.c) void) c_int;
pub extern var PyContext_Type: PyTypeObject;
pub const struct__pycontextobject = opaque {};
pub const PyContext = struct__pycontextobject;
pub extern var PyContextVar_Type: PyTypeObject;
pub const struct__pycontextvarobject = opaque {};
pub const PyContextVar = struct__pycontextvarobject;
pub extern var PyContextToken_Type: PyTypeObject;
pub const struct__pycontexttokenobject = opaque {};
pub const PyContextToken = struct__pycontexttokenobject;
pub extern fn PyContext_New() [*c]PyObject;
pub extern fn PyContext_Copy([*c]PyObject) [*c]PyObject;
pub extern fn PyContext_CopyCurrent() [*c]PyObject;
pub extern fn PyContext_Enter([*c]PyObject) c_int;
pub extern fn PyContext_Exit([*c]PyObject) c_int;
pub const Py_CONTEXT_SWITCHED: c_int = 1;
pub const PyContextEvent = c_uint;
pub const PyContext_WatchCallback = ?*const fn (PyContextEvent, [*c]PyObject) callconv(.c) c_int;
pub extern fn PyContext_AddWatcher(callback: PyContext_WatchCallback) c_int;
pub extern fn PyContext_ClearWatcher(watcher_id: c_int) c_int;
pub extern fn PyContextVar_New(name: [*c]const u8, default_value: [*c]PyObject) [*c]PyObject;
pub extern fn PyContextVar_Get(@"var": [*c]PyObject, default_value: [*c]PyObject, value: [*c][*c]PyObject) c_int;
pub extern fn PyContextVar_Set(@"var": [*c]PyObject, value: [*c]PyObject) [*c]PyObject;
pub extern fn PyContextVar_Reset(@"var": [*c]PyObject, token: [*c]PyObject) c_int;
pub extern fn PyArg_Parse([*c]PyObject, [*c]const u8, ...) c_int;
pub extern fn PyArg_ParseTuple([*c]PyObject, [*c]const u8, ...) c_int;
pub extern fn PyArg_ParseTupleAndKeywords([*c]PyObject, [*c]PyObject, [*c]const u8, [*c]const [*c]u8, ...) c_int;
pub extern fn PyArg_VaParse([*c]PyObject, [*c]const u8, [*c]struct___va_list_tag_3) c_int;
pub extern fn PyArg_VaParseTupleAndKeywords([*c]PyObject, [*c]PyObject, [*c]const u8, [*c]const [*c]u8, [*c]struct___va_list_tag_3) c_int;
pub extern fn PyArg_ValidateKeywordArguments([*c]PyObject) c_int;
pub extern fn PyArg_UnpackTuple([*c]PyObject, [*c]const u8, Py_ssize_t, Py_ssize_t, ...) c_int;
pub extern fn Py_BuildValue([*c]const u8, ...) [*c]PyObject;
pub extern fn Py_VaBuildValue([*c]const u8, [*c]struct___va_list_tag_3) [*c]PyObject;
pub extern fn PyModule_AddObjectRef(mod: [*c]PyObject, name: [*c]const u8, value: [*c]PyObject) c_int;
pub extern fn PyModule_Add(mod: [*c]PyObject, name: [*c]const u8, value: [*c]PyObject) c_int;
pub extern fn PyModule_AddObject(mod: [*c]PyObject, [*c]const u8, value: [*c]PyObject) c_int;
pub extern fn PyModule_AddIntConstant([*c]PyObject, [*c]const u8, c_long) c_int;
pub extern fn PyModule_AddStringConstant([*c]PyObject, [*c]const u8, [*c]const u8) c_int;
pub extern fn PyModule_AddType(module: [*c]PyObject, @"type": [*c]PyTypeObject) c_int;
pub extern fn PyModule_SetDocString([*c]PyObject, [*c]const u8) c_int;
pub extern fn PyModule_AddFunctions([*c]PyObject, [*c]PyMethodDef) c_int;
pub extern fn PyModule_ExecDef(module: [*c]PyObject, def: [*c]PyModuleDef) c_int;
pub extern fn PyModule_Create2([*c]PyModuleDef, apiver: c_int) [*c]PyObject;
pub extern fn PyModule_FromDefAndSpec2(def: [*c]PyModuleDef, spec: [*c]PyObject, module_api_version: c_int) [*c]PyObject;
pub const _PyOnceFlag = extern struct {
    v: u8 = 0,
};
pub const struct__PyArg_Parser = extern struct {
    format: [*c]const u8 = null,
    keywords: [*c]const [*c]const u8 = null,
    fname: [*c]const u8 = null,
    custom_msg: [*c]const u8 = null,
    once: _PyOnceFlag = @import("std").mem.zeroes(_PyOnceFlag),
    is_kwtuple_owned: c_int = 0,
    pos: c_int = 0,
    min: c_int = 0,
    max: c_int = 0,
    kwtuple: [*c]PyObject = null,
    next: [*c]struct__PyArg_Parser = null,
};
pub const _PyArg_Parser = struct__PyArg_Parser;
pub extern fn _PyArg_ParseTupleAndKeywordsFast([*c]PyObject, [*c]PyObject, [*c]struct__PyArg_Parser, ...) c_int;
pub const PyCompilerFlags = extern struct {
    cf_flags: c_int = 0,
    cf_feature_version: c_int = 0,
    pub const PyEval_MergeCompilerFlags = __root.PyEval_MergeCompilerFlags;
    pub const MergeCompilerFlags = __root.PyEval_MergeCompilerFlags;
};
pub extern fn PyCompile_OpcodeStackEffect(opcode: c_int, oparg: c_int) c_int;
pub extern fn PyCompile_OpcodeStackEffectWithJump(opcode: c_int, oparg: c_int, jump: c_int) c_int;
pub extern fn Py_CompileString([*c]const u8, [*c]const u8, c_int) [*c]PyObject;
pub extern fn PyErr_Print() void;
pub extern fn PyErr_PrintEx(c_int) void;
pub extern fn PyErr_Display([*c]PyObject, [*c]PyObject, [*c]PyObject) void;
pub extern fn PyErr_DisplayException([*c]PyObject) void;
pub extern var PyOS_InputHook: ?*const fn () callconv(.c) c_int;
pub extern fn PyRun_SimpleStringFlags([*c]const u8, [*c]PyCompilerFlags) c_int;
pub extern fn PyRun_AnyFileExFlags(fp: [*c]FILE, filename: [*c]const u8, closeit: c_int, flags: [*c]PyCompilerFlags) c_int;
pub extern fn PyRun_SimpleFileExFlags(fp: [*c]FILE, filename: [*c]const u8, closeit: c_int, flags: [*c]PyCompilerFlags) c_int;
pub extern fn PyRun_InteractiveOneFlags(fp: [*c]FILE, filename: [*c]const u8, flags: [*c]PyCompilerFlags) c_int;
pub extern fn PyRun_InteractiveOneObject(fp: [*c]FILE, filename: [*c]PyObject, flags: [*c]PyCompilerFlags) c_int;
pub extern fn PyRun_InteractiveLoopFlags(fp: [*c]FILE, filename: [*c]const u8, flags: [*c]PyCompilerFlags) c_int;
pub extern fn PyRun_StringFlags([*c]const u8, c_int, [*c]PyObject, [*c]PyObject, [*c]PyCompilerFlags) [*c]PyObject;
pub extern fn PyRun_FileExFlags(fp: [*c]FILE, filename: [*c]const u8, start: c_int, globals: [*c]PyObject, locals: [*c]PyObject, closeit: c_int, flags: [*c]PyCompilerFlags) [*c]PyObject;
pub extern fn Py_CompileStringExFlags(str: [*c]const u8, filename: [*c]const u8, start: c_int, flags: [*c]PyCompilerFlags, optimize: c_int) [*c]PyObject;
pub extern fn Py_CompileStringObject(str: [*c]const u8, filename: [*c]PyObject, start: c_int, flags: [*c]PyCompilerFlags, optimize: c_int) [*c]PyObject;
pub extern fn PyRun_String(str: [*c]const u8, s: c_int, g: [*c]PyObject, l: [*c]PyObject) [*c]PyObject;
pub extern fn PyRun_AnyFile(fp: [*c]FILE, name: [*c]const u8) c_int;
pub extern fn PyRun_AnyFileEx(fp: [*c]FILE, name: [*c]const u8, closeit: c_int) c_int;
pub extern fn PyRun_AnyFileFlags([*c]FILE, [*c]const u8, [*c]PyCompilerFlags) c_int;
pub extern fn PyRun_SimpleString(s: [*c]const u8) c_int;
pub extern fn PyRun_SimpleFile(f: [*c]FILE, p: [*c]const u8) c_int;
pub extern fn PyRun_SimpleFileEx(f: [*c]FILE, p: [*c]const u8, c: c_int) c_int;
pub extern fn PyRun_InteractiveOne(f: [*c]FILE, p: [*c]const u8) c_int;
pub extern fn PyRun_InteractiveLoop(f: [*c]FILE, p: [*c]const u8) c_int;
pub extern fn PyRun_File(fp: [*c]FILE, p: [*c]const u8, s: c_int, g: [*c]PyObject, l: [*c]PyObject) [*c]PyObject;
pub extern fn PyRun_FileEx(fp: [*c]FILE, p: [*c]const u8, s: c_int, g: [*c]PyObject, l: [*c]PyObject, c: c_int) [*c]PyObject;
pub extern fn PyRun_FileFlags(fp: [*c]FILE, p: [*c]const u8, s: c_int, g: [*c]PyObject, l: [*c]PyObject, flags: [*c]PyCompilerFlags) [*c]PyObject;
pub extern fn PyOS_Readline([*c]FILE, [*c]FILE, [*c]const u8) [*c]u8;
pub extern var PyOS_ReadlineFunctionPointer: ?*const fn ([*c]FILE, [*c]FILE, [*c]const u8) callconv(.c) [*c]u8;
pub extern fn Py_Initialize() void;
pub extern fn Py_InitializeEx(c_int) void;
pub extern fn Py_Finalize() void;
pub extern fn Py_FinalizeEx() c_int;
pub extern fn Py_IsInitialized() c_int;
pub extern fn Py_NewInterpreter() ?*PyThreadState;
pub extern fn Py_EndInterpreter(?*PyThreadState) void;
pub extern fn Py_AtExit(func: ?*const fn () callconv(.c) void) c_int;
pub extern fn Py_Exit(c_int) noreturn;
pub extern fn Py_Main(argc: c_int, argv: [*c][*c]wchar_t) c_int;
pub extern fn Py_BytesMain(argc: c_int, argv: [*c][*c]u8) c_int;
pub extern fn Py_SetProgramName([*c]const wchar_t) void;
pub extern fn Py_GetProgramName() [*c]wchar_t;
pub extern fn Py_SetPythonHome([*c]const wchar_t) void;
pub extern fn Py_GetPythonHome() [*c]wchar_t;
pub extern fn Py_GetProgramFullPath() [*c]wchar_t;
pub extern fn Py_GetPrefix() [*c]wchar_t;
pub extern fn Py_GetExecPrefix() [*c]wchar_t;
pub extern fn Py_GetPath() [*c]wchar_t;
pub extern fn Py_GetVersion() [*c]const u8;
pub extern fn Py_GetPlatform() [*c]const u8;
pub extern fn Py_GetCopyright() [*c]const u8;
pub extern fn Py_GetCompiler() [*c]const u8;
pub extern fn Py_GetBuildInfo() [*c]const u8;
pub const PyOS_sighandler_t = ?*const fn (c_int) callconv(.c) void;
pub extern fn PyOS_getsig(c_int) PyOS_sighandler_t;
pub extern fn PyOS_setsig(c_int, PyOS_sighandler_t) PyOS_sighandler_t;
pub extern const Py_Version: c_ulong;
pub extern fn Py_IsFinalizing() c_int;
pub extern fn Py_FrozenMain(argc: c_int, argv: [*c][*c]u8) c_int;
pub extern fn Py_PreInitialize(src_config: [*c]const PyPreConfig) PyStatus;
pub extern fn Py_PreInitializeFromBytesArgs(src_config: [*c]const PyPreConfig, argc: Py_ssize_t, argv: [*c][*c]u8) PyStatus;
pub extern fn Py_PreInitializeFromArgs(src_config: [*c]const PyPreConfig, argc: Py_ssize_t, argv: [*c][*c]wchar_t) PyStatus;
pub extern fn Py_InitializeFromConfig(config: [*c]const PyConfig) PyStatus;
pub extern fn Py_RunMain() c_int;
pub extern fn Py_ExitStatusException(err: PyStatus) noreturn;
pub extern fn Py_FdIsInteractive([*c]FILE, [*c]const u8) c_int;
pub const PyInterpreterConfig = extern struct {
    use_main_obmalloc: c_int = 0,
    allow_fork: c_int = 0,
    allow_exec: c_int = 0,
    allow_threads: c_int = 0,
    allow_daemon_threads: c_int = 0,
    check_multi_interp_extensions: c_int = 0,
    gil: c_int = 0,
};
pub extern fn Py_NewInterpreterFromConfig(tstate_p: [*c]?*PyThreadState, config: [*c]const PyInterpreterConfig) PyStatus;
pub const atexit_datacallbackfunc = ?*const fn (?*anyopaque) callconv(.c) void;
pub extern fn PyUnstable_AtExit(?*PyInterpreterState, atexit_datacallbackfunc, ?*anyopaque) c_int;
pub extern fn PyEval_EvalCode([*c]PyObject, [*c]PyObject, [*c]PyObject) [*c]PyObject;
pub extern fn PyEval_EvalCodeEx(co: [*c]PyObject, globals: [*c]PyObject, locals: [*c]PyObject, args: [*c]const [*c]PyObject, argc: c_int, kwds: [*c]const [*c]PyObject, kwdc: c_int, defs: [*c]const [*c]PyObject, defc: c_int, kwdefs: [*c]PyObject, closure: [*c]PyObject) [*c]PyObject;
pub extern fn PyEval_GetBuiltins() [*c]PyObject;
pub extern fn PyEval_GetGlobals() [*c]PyObject;
pub extern fn PyEval_GetLocals() [*c]PyObject;
pub extern fn PyEval_GetFrame() ?*PyFrameObject;
pub extern fn PyEval_GetFrameBuiltins() [*c]PyObject;
pub extern fn PyEval_GetFrameGlobals() [*c]PyObject;
pub extern fn PyEval_GetFrameLocals() [*c]PyObject;
pub extern fn Py_AddPendingCall(func: ?*const fn (?*anyopaque) callconv(.c) c_int, arg: ?*anyopaque) c_int;
pub extern fn Py_MakePendingCalls() c_int;
pub extern fn Py_SetRecursionLimit(c_int) void;
pub extern fn Py_GetRecursionLimit() c_int;
pub extern fn Py_EnterRecursiveCall(where: [*c]const u8) c_int;
pub extern fn Py_LeaveRecursiveCall() void;
pub extern fn PyEval_GetFuncName([*c]PyObject) [*c]const u8;
pub extern fn PyEval_GetFuncDesc([*c]PyObject) [*c]const u8;
pub extern fn PyEval_EvalFrame(?*PyFrameObject) [*c]PyObject;
pub extern fn PyEval_EvalFrameEx(f: ?*PyFrameObject, exc: c_int) [*c]PyObject;
pub extern fn PyEval_SaveThread() ?*PyThreadState;
pub extern fn PyEval_RestoreThread(?*PyThreadState) void;
pub extern fn PyEval_InitThreads() void;
pub extern fn PyEval_AcquireThread(tstate: ?*PyThreadState) void;
pub extern fn PyEval_ReleaseThread(tstate: ?*PyThreadState) void;
pub extern fn PyEval_SetProfile(Py_tracefunc, [*c]PyObject) void;
pub extern fn PyEval_SetProfileAllThreads(Py_tracefunc, [*c]PyObject) void;
pub extern fn PyEval_SetTrace(Py_tracefunc, [*c]PyObject) void;
pub extern fn PyEval_SetTraceAllThreads(Py_tracefunc, [*c]PyObject) void;
pub extern fn PyEval_MergeCompilerFlags(cf: [*c]PyCompilerFlags) c_int;
pub extern fn _PyEval_EvalFrameDefault(tstate: ?*PyThreadState, f: ?*struct__PyInterpreterFrame, exc: c_int) [*c]PyObject;
pub extern fn PyUnstable_Eval_RequestCodeExtraIndex(freefunc) Py_ssize_t;
pub fn _PyEval_RequestCodeExtraIndex(arg_f: freefunc) callconv(.c) Py_ssize_t {
    var f = arg_f;
    _ = &f;
    return PyUnstable_Eval_RequestCodeExtraIndex(f);
}
pub extern fn _PyEval_SliceIndex([*c]PyObject, [*c]Py_ssize_t) c_int;
pub extern fn _PyEval_SliceIndexNotNone([*c]PyObject, [*c]Py_ssize_t) c_int;
pub const PerfMapState = extern struct {
    perf_map: [*c]FILE = null,
    map_lock: PyThread_type_lock = null,
};
pub extern fn PyUnstable_PerfMapState_Init() c_int;
pub extern fn PyUnstable_WritePerfMapEntry(code_addr: ?*const anyopaque, code_size: c_uint, entry_name: [*c]const u8) c_int;
pub extern fn PyUnstable_PerfMapState_Fini() void;
pub extern fn PyUnstable_CopyPerfMapFile(parent_filename: [*c]const u8) c_int;
pub extern fn PyUnstable_PerfTrampoline_CompileCode([*c]PyCodeObject) c_int;
pub extern fn PyUnstable_PerfTrampoline_SetPersistAfterFork(enable: c_int) c_int;
pub extern fn PySys_GetObject([*c]const u8) [*c]PyObject;
pub extern fn PySys_SetObject([*c]const u8, [*c]PyObject) c_int;
pub extern fn PySys_SetArgv(c_int, [*c][*c]wchar_t) void;
pub extern fn PySys_SetArgvEx(c_int, [*c][*c]wchar_t, c_int) void;
pub extern fn PySys_WriteStdout(format: [*c]const u8, ...) void;
pub extern fn PySys_WriteStderr(format: [*c]const u8, ...) void;
pub extern fn PySys_FormatStdout(format: [*c]const u8, ...) void;
pub extern fn PySys_FormatStderr(format: [*c]const u8, ...) void;
pub extern fn PySys_ResetWarnOptions() void;
pub extern fn PySys_GetXOptions() [*c]PyObject;
pub extern fn PySys_Audit(event: [*c]const u8, argFormat: [*c]const u8, ...) c_int;
pub extern fn PySys_AuditTuple(event: [*c]const u8, args: [*c]PyObject) c_int;
pub const Py_AuditHookFunction = ?*const fn ([*c]const u8, [*c]PyObject, ?*anyopaque) callconv(.c) c_int;
pub extern fn PySys_AddAuditHook(Py_AuditHookFunction, ?*anyopaque) c_int;
pub extern fn PyOS_FSPath(path: [*c]PyObject) [*c]PyObject;
pub extern fn PyOS_InterruptOccurred() c_int;
pub extern fn PyOS_BeforeFork() void;
pub extern fn PyOS_AfterFork_Parent() void;
pub extern fn PyOS_AfterFork_Child() void;
pub extern fn PyOS_AfterFork() void;
pub extern fn PyImport_GetMagicNumber() c_long;
pub extern fn PyImport_GetMagicTag() [*c]const u8;
pub extern fn PyImport_ExecCodeModule(name: [*c]const u8, co: [*c]PyObject) [*c]PyObject;
pub extern fn PyImport_ExecCodeModuleEx(name: [*c]const u8, co: [*c]PyObject, pathname: [*c]const u8) [*c]PyObject;
pub extern fn PyImport_ExecCodeModuleWithPathnames(name: [*c]const u8, co: [*c]PyObject, pathname: [*c]const u8, cpathname: [*c]const u8) [*c]PyObject;
pub extern fn PyImport_ExecCodeModuleObject(name: [*c]PyObject, co: [*c]PyObject, pathname: [*c]PyObject, cpathname: [*c]PyObject) [*c]PyObject;
pub extern fn PyImport_GetModuleDict() [*c]PyObject;
pub extern fn PyImport_GetModule(name: [*c]PyObject) [*c]PyObject;
pub extern fn PyImport_AddModuleObject(name: [*c]PyObject) [*c]PyObject;
pub extern fn PyImport_AddModule(name: [*c]const u8) [*c]PyObject;
pub extern fn PyImport_AddModuleRef(name: [*c]const u8) [*c]PyObject;
pub extern fn PyImport_ImportModule(name: [*c]const u8) [*c]PyObject;
pub extern fn PyImport_ImportModuleNoBlock(name: [*c]const u8) [*c]PyObject;
pub extern fn PyImport_ImportModuleLevel(name: [*c]const u8, globals: [*c]PyObject, locals: [*c]PyObject, fromlist: [*c]PyObject, level: c_int) [*c]PyObject;
pub extern fn PyImport_ImportModuleLevelObject(name: [*c]PyObject, globals: [*c]PyObject, locals: [*c]PyObject, fromlist: [*c]PyObject, level: c_int) [*c]PyObject;
pub extern fn PyImport_GetImporter(path: [*c]PyObject) [*c]PyObject;
pub extern fn PyImport_Import(name: [*c]PyObject) [*c]PyObject;
pub extern fn PyImport_ReloadModule(m: [*c]PyObject) [*c]PyObject;
pub extern fn PyImport_ImportFrozenModuleObject(name: [*c]PyObject) c_int;
pub extern fn PyImport_ImportFrozenModule(name: [*c]const u8) c_int;
pub extern fn PyImport_AppendInittab(name: [*c]const u8, initfunc: ?*const fn () callconv(.c) [*c]PyObject) c_int;
pub const struct__inittab = extern struct {
    name: [*c]const u8 = null,
    initfunc: ?*const fn () callconv(.c) [*c]PyObject = null,
    pub const PyImport_ExtendInittab = __root.PyImport_ExtendInittab;
    pub const ExtendInittab = __root.PyImport_ExtendInittab;
};
pub extern var PyImport_Inittab: [*c]struct__inittab;
pub extern fn PyImport_ExtendInittab(newtab: [*c]struct__inittab) c_int;
pub const struct__frozen = extern struct {
    name: [*c]const u8 = null,
    code: [*c]const u8 = null,
    size: c_int = 0,
    is_package: c_int = 0,
};
pub extern var PyImport_FrozenModules: [*c]const struct__frozen;
pub extern fn PyImport_ImportModuleAttr(mod_name: [*c]PyObject, attr_name: [*c]PyObject) [*c]PyObject;
pub extern fn PyImport_ImportModuleAttrString(mod_name: [*c]const u8, attr_name: [*c]const u8) [*c]PyObject;
pub extern fn PyObject_CallNoArgs(func: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_Call(callable: [*c]PyObject, args: [*c]PyObject, kwargs: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_CallObject(callable: [*c]PyObject, args: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_CallFunction(callable: [*c]PyObject, format: [*c]const u8, ...) [*c]PyObject;
pub extern fn PyObject_CallMethod(obj: [*c]PyObject, name: [*c]const u8, format: [*c]const u8, ...) [*c]PyObject;
pub extern fn PyObject_CallFunctionObjArgs(callable: [*c]PyObject, ...) [*c]PyObject;
pub extern fn PyObject_CallMethodObjArgs(obj: [*c]PyObject, name: [*c]PyObject, ...) [*c]PyObject;
pub extern fn PyVectorcall_NARGS(nargsf: usize) Py_ssize_t;
pub extern fn PyVectorcall_Call(callable: [*c]PyObject, tuple: [*c]PyObject, dict: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_Vectorcall(callable: [*c]PyObject, args: [*c]const [*c]PyObject, nargsf: usize, kwnames: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_VectorcallMethod(name: [*c]PyObject, args: [*c]const [*c]PyObject, nargsf: usize, kwnames: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_Type(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_Size(o: [*c]PyObject) Py_ssize_t;
pub extern fn PyObject_Length(o: [*c]PyObject) Py_ssize_t;
pub extern fn PyObject_GetItem(o: [*c]PyObject, key: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_SetItem(o: [*c]PyObject, key: [*c]PyObject, v: [*c]PyObject) c_int;
pub extern fn PyObject_DelItemString(o: [*c]PyObject, key: [*c]const u8) c_int;
pub extern fn PyObject_DelItem(o: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern fn PyObject_Format(obj: [*c]PyObject, format_spec: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_GetIter([*c]PyObject) [*c]PyObject;
pub extern fn PyObject_GetAIter([*c]PyObject) [*c]PyObject;
pub extern fn PyIter_Check([*c]PyObject) c_int;
pub extern fn PyAIter_Check([*c]PyObject) c_int;
pub extern fn PyIter_NextItem(iter: [*c]PyObject, item: [*c][*c]PyObject) c_int;
pub extern fn PyIter_Next([*c]PyObject) [*c]PyObject;
pub extern fn PyIter_Send([*c]PyObject, [*c]PyObject, [*c][*c]PyObject) PySendResult;
pub extern fn PyNumber_Check(o: [*c]PyObject) c_int;
pub extern fn PyNumber_Add(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Subtract(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Multiply(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_MatrixMultiply(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_FloorDivide(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_TrueDivide(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Remainder(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Divmod(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Power(o1: [*c]PyObject, o2: [*c]PyObject, o3: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Negative(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Positive(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Absolute(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Invert(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Lshift(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Rshift(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_And(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Xor(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Or(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyIndex_Check([*c]PyObject) c_int;
pub extern fn PyNumber_Index(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_AsSsize_t(o: [*c]PyObject, exc: [*c]PyObject) Py_ssize_t;
pub extern fn PyNumber_Long(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_Float(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceAdd(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceSubtract(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceMultiply(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceMatrixMultiply(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceFloorDivide(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceTrueDivide(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceRemainder(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlacePower(o1: [*c]PyObject, o2: [*c]PyObject, o3: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceLshift(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceRshift(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceAnd(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceXor(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_InPlaceOr(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PyNumber_ToBase(n: [*c]PyObject, base: c_int) [*c]PyObject;
pub extern fn PySequence_Check(o: [*c]PyObject) c_int;
pub extern fn PySequence_Size(o: [*c]PyObject) Py_ssize_t;
pub extern fn PySequence_Length(o: [*c]PyObject) Py_ssize_t;
pub extern fn PySequence_Concat(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PySequence_Repeat(o: [*c]PyObject, count: Py_ssize_t) [*c]PyObject;
pub extern fn PySequence_GetItem(o: [*c]PyObject, i: Py_ssize_t) [*c]PyObject;
pub extern fn PySequence_GetSlice(o: [*c]PyObject, @"i1": Py_ssize_t, @"i2": Py_ssize_t) [*c]PyObject;
pub extern fn PySequence_SetItem(o: [*c]PyObject, i: Py_ssize_t, v: [*c]PyObject) c_int;
pub extern fn PySequence_DelItem(o: [*c]PyObject, i: Py_ssize_t) c_int;
pub extern fn PySequence_SetSlice(o: [*c]PyObject, @"i1": Py_ssize_t, @"i2": Py_ssize_t, v: [*c]PyObject) c_int;
pub extern fn PySequence_DelSlice(o: [*c]PyObject, @"i1": Py_ssize_t, @"i2": Py_ssize_t) c_int;
pub extern fn PySequence_Tuple(o: [*c]PyObject) [*c]PyObject;
pub extern fn PySequence_List(o: [*c]PyObject) [*c]PyObject;
pub extern fn PySequence_Fast(o: [*c]PyObject, m: [*c]const u8) [*c]PyObject;
pub extern fn PySequence_Count(o: [*c]PyObject, value: [*c]PyObject) Py_ssize_t;
pub extern fn PySequence_Contains(seq: [*c]PyObject, ob: [*c]PyObject) c_int;
pub extern fn PySequence_In(o: [*c]PyObject, value: [*c]PyObject) c_int;
pub extern fn PySequence_Index(o: [*c]PyObject, value: [*c]PyObject) Py_ssize_t;
pub extern fn PySequence_InPlaceConcat(o1: [*c]PyObject, o2: [*c]PyObject) [*c]PyObject;
pub extern fn PySequence_InPlaceRepeat(o: [*c]PyObject, count: Py_ssize_t) [*c]PyObject;
pub extern fn PyMapping_Check(o: [*c]PyObject) c_int;
pub extern fn PyMapping_Size(o: [*c]PyObject) Py_ssize_t;
pub extern fn PyMapping_Length(o: [*c]PyObject) Py_ssize_t;
pub extern fn PyMapping_HasKeyString(o: [*c]PyObject, key: [*c]const u8) c_int;
pub extern fn PyMapping_HasKey(o: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern fn PyMapping_HasKeyWithError(o: [*c]PyObject, key: [*c]PyObject) c_int;
pub extern fn PyMapping_HasKeyStringWithError(o: [*c]PyObject, key: [*c]const u8) c_int;
pub extern fn PyMapping_Keys(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyMapping_Values(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyMapping_Items(o: [*c]PyObject) [*c]PyObject;
pub extern fn PyMapping_GetItemString(o: [*c]PyObject, key: [*c]const u8) [*c]PyObject;
pub extern fn PyMapping_GetOptionalItem([*c]PyObject, [*c]PyObject, [*c][*c]PyObject) c_int;
pub extern fn PyMapping_GetOptionalItemString([*c]PyObject, [*c]const u8, [*c][*c]PyObject) c_int;
pub extern fn PyMapping_SetItemString(o: [*c]PyObject, key: [*c]const u8, value: [*c]PyObject) c_int;
pub extern fn PyObject_IsInstance(object: [*c]PyObject, typeorclass: [*c]PyObject) c_int;
pub extern fn PyObject_IsSubclass(object: [*c]PyObject, typeorclass: [*c]PyObject) c_int;
pub extern fn _PyObject_CallMethodId(obj: [*c]PyObject, name: [*c]_Py_Identifier, format: [*c]const u8, ...) [*c]PyObject;
pub extern fn _PyStack_AsDict(values: [*c]const [*c]PyObject, kwnames: [*c]PyObject) [*c]PyObject;
pub fn _PyVectorcall_NARGS(arg_n: usize) callconv(.c) Py_ssize_t {
    var n = arg_n;
    _ = &n;
    return @bitCast(@as(c_ulong, @truncate(n & ~(@as(usize, @bitCast(@as(c_long, @as(c_int, 1)))) << @intCast((@as(c_ulong, 8) *% @sizeOf(usize)) -% @as(c_ulong, 1))))));
}
pub extern fn PyVectorcall_Function(callable: [*c]PyObject) vectorcallfunc;
pub extern fn PyObject_VectorcallDict(callable: [*c]PyObject, args: [*c]const [*c]PyObject, nargsf: usize, kwargs: [*c]PyObject) [*c]PyObject;
pub extern fn PyObject_CallOneArg(func: [*c]PyObject, arg: [*c]PyObject) [*c]PyObject;
pub fn PyObject_CallMethodNoArgs(arg_self: [*c]PyObject, arg_name: [*c]PyObject) callconv(.c) [*c]PyObject {
    var self = arg_self;
    _ = &self;
    var name = arg_name;
    _ = &name;
    var nargsf: usize = @as(usize, 1) | (@as(usize, @bitCast(@as(c_long, @as(c_int, 1)))) << @intCast((@as(c_ulong, 8) *% @sizeOf(usize)) -% @as(c_ulong, 1)));
    _ = &nargsf;
    return PyObject_VectorcallMethod(name, &self, nargsf, null);
}
pub fn PyObject_CallMethodOneArg(arg_self: [*c]PyObject, arg_name: [*c]PyObject, arg_arg: [*c]PyObject) callconv(.c) [*c]PyObject {
    var self = arg_self;
    _ = &self;
    var name = arg_name;
    _ = &name;
    var arg = arg_arg;
    _ = &arg;
    var args: [2][*c]PyObject = [2][*c]PyObject{
        self,
        arg,
    };
    _ = &args;
    var nargsf: usize = @as(usize, 2) | (@as(usize, @bitCast(@as(c_long, @as(c_int, 1)))) << @intCast((@as(c_ulong, 8) *% @sizeOf(usize)) -% @as(c_ulong, 1)));
    _ = &nargsf;
    _ = @as(c_int, 0);
    return PyObject_VectorcallMethod(name, @ptrCast(@alignCast(&args)), nargsf, null);
}
pub extern fn PyObject_LengthHint(o: [*c]PyObject, Py_ssize_t) Py_ssize_t;
pub extern var PyFilter_Type: PyTypeObject;
pub extern var PyMap_Type: PyTypeObject;
pub extern var PyZip_Type: PyTypeObject;
pub extern const _Py_ctype_table: [256]c_uint;
pub extern const _Py_ctype_tolower: [256]u8;
pub extern const _Py_ctype_toupper: [256]u8;
pub extern fn PyOS_string_to_double(str: [*c]const u8, endptr: [*c][*c]u8, overflow_exception: [*c]PyObject) f64;
pub extern fn PyOS_double_to_string(val: f64, format_code: u8, precision: c_int, flags: c_int, @"type": [*c]c_int) [*c]u8;
pub extern fn PyOS_mystrnicmp([*c]const u8, [*c]const u8, Py_ssize_t) c_int;
pub extern fn PyOS_mystricmp([*c]const u8, [*c]const u8) c_int;
pub const struct_stat = extern struct {
    st_dev: __dev_t = 0,
    st_ino: __ino_t = 0,
    st_nlink: __nlink_t = 0,
    st_mode: __mode_t = 0,
    st_uid: __uid_t = 0,
    st_gid: __gid_t = 0,
    __pad0: c_int = 0,
    st_rdev: __dev_t = 0,
    st_size: __off_t = 0,
    st_blksize: __blksize_t = 0,
    st_blocks: __blkcnt_t = 0,
    st_atim: struct_timespec = @import("std").mem.zeroes(struct_timespec),
    st_mtim: struct_timespec = @import("std").mem.zeroes(struct_timespec),
    st_ctim: struct_timespec = @import("std").mem.zeroes(struct_timespec),
    __glibc_reserved: [3]__syscall_slong_t = @import("std").mem.zeroes([3]__syscall_slong_t),
};
pub const struct_stat64 = extern struct {
    st_dev: __dev_t = 0,
    st_ino: __ino64_t = 0,
    st_nlink: __nlink_t = 0,
    st_mode: __mode_t = 0,
    st_uid: __uid_t = 0,
    st_gid: __gid_t = 0,
    __pad0: c_int = 0,
    st_rdev: __dev_t = 0,
    st_size: __off_t = 0,
    st_blksize: __blksize_t = 0,
    st_blocks: __blkcnt64_t = 0,
    st_atim: struct_timespec = @import("std").mem.zeroes(struct_timespec),
    st_mtim: struct_timespec = @import("std").mem.zeroes(struct_timespec),
    st_ctim: struct_timespec = @import("std").mem.zeroes(struct_timespec),
    __glibc_reserved: [3]__syscall_slong_t = @import("std").mem.zeroes([3]__syscall_slong_t),
};
pub extern fn stat(noalias __file: [*c]const u8, noalias __buf: [*c]struct_stat) c_int;
pub extern fn fstat(__fd: c_int, __buf: [*c]struct_stat) c_int;
pub extern fn stat64(noalias __file: [*c]const u8, noalias __buf: [*c]struct_stat64) c_int;
pub extern fn fstat64(__fd: c_int, __buf: [*c]struct_stat64) c_int;
pub extern fn fstatat(__fd: c_int, noalias __file: [*c]const u8, noalias __buf: [*c]struct_stat, __flag: c_int) c_int;
pub extern fn fstatat64(__fd: c_int, noalias __file: [*c]const u8, noalias __buf: [*c]struct_stat64, __flag: c_int) c_int;
pub extern fn lstat(noalias __file: [*c]const u8, noalias __buf: [*c]struct_stat) c_int;
pub extern fn lstat64(noalias __file: [*c]const u8, noalias __buf: [*c]struct_stat64) c_int;
pub extern fn chmod(__file: [*c]const u8, __mode: __mode_t) c_int;
pub extern fn lchmod(__file: [*c]const u8, __mode: __mode_t) c_int;
pub extern fn fchmod(__fd: c_int, __mode: __mode_t) c_int;
pub extern fn fchmodat(__fd: c_int, __file: [*c]const u8, __mode: __mode_t, __flag: c_int) c_int;
pub extern fn umask(__mask: __mode_t) __mode_t;
pub extern fn getumask() __mode_t;
pub extern fn mkdir(__path: [*c]const u8, __mode: __mode_t) c_int;
pub extern fn mkdirat(__fd: c_int, __path: [*c]const u8, __mode: __mode_t) c_int;
pub extern fn mknod(__path: [*c]const u8, __mode: __mode_t, __dev: __dev_t) c_int;
pub extern fn mknodat(__fd: c_int, __path: [*c]const u8, __mode: __mode_t, __dev: __dev_t) c_int;
pub extern fn mkfifo(__path: [*c]const u8, __mode: __mode_t) c_int;
pub extern fn mkfifoat(__fd: c_int, __path: [*c]const u8, __mode: __mode_t) c_int;
pub extern fn utimensat(__fd: c_int, __path: [*c]const u8, __times: [*c]const struct_timespec, __flags: c_int) c_int;
pub extern fn futimens(__fd: c_int, __times: [*c]const struct_timespec) c_int;
pub const __s8 = i8;
pub const __u8 = u8;
pub const __s16 = c_short;
pub const __u16 = c_ushort;
pub const __s32 = c_int;
pub const __u32 = c_uint;
pub const __s64 = c_longlong;
pub const __u64 = c_ulonglong;
pub const __kernel_fd_set = extern struct {
    fds_bits: [16]c_ulong = @import("std").mem.zeroes([16]c_ulong),
};
pub const __kernel_sighandler_t = ?*const fn (c_int) callconv(.c) void;
pub const __kernel_key_t = c_int;
pub const __kernel_mqd_t = c_int;
pub const __kernel_old_uid_t = c_ushort;
pub const __kernel_old_gid_t = c_ushort;
pub const __kernel_old_dev_t = c_ulong;
pub const __kernel_long_t = c_long;
pub const __kernel_ulong_t = c_ulong;
pub const __kernel_ino_t = __kernel_ulong_t;
pub const __kernel_mode_t = c_uint;
pub const __kernel_pid_t = c_int;
pub const __kernel_ipc_pid_t = c_int;
pub const __kernel_uid_t = c_uint;
pub const __kernel_gid_t = c_uint;
pub const __kernel_suseconds_t = __kernel_long_t;
pub const __kernel_daddr_t = c_int;
pub const __kernel_uid32_t = c_uint;
pub const __kernel_gid32_t = c_uint;
pub const __kernel_size_t = __kernel_ulong_t;
pub const __kernel_ssize_t = __kernel_long_t;
pub const __kernel_ptrdiff_t = __kernel_long_t;
pub const __kernel_fsid_t = extern struct {
    val: [2]c_int = @import("std").mem.zeroes([2]c_int),
};
pub const __kernel_off_t = __kernel_long_t;
pub const __kernel_loff_t = c_longlong;
pub const __kernel_old_time_t = __kernel_long_t;
pub const __kernel_time_t = __kernel_long_t;
pub const __kernel_time64_t = c_longlong;
pub const __kernel_clock_t = __kernel_long_t;
pub const __kernel_timer_t = c_int;
pub const __kernel_clockid_t = c_int;
pub const __kernel_caddr_t = [*c]u8;
pub const __kernel_uid16_t = c_ushort;
pub const __kernel_gid16_t = c_ushort;
pub const __s128 = i128;
pub const __u128 = u128;
pub const __le16 = __u16;
pub const __be16 = __u16;
pub const __le32 = __u32;
pub const __be32 = __u32;
pub const __le64 = __u64;
pub const __be64 = __u64;
pub const __sum16 = __u16;
pub const __wsum = __u32;
pub const __poll_t = c_uint;
pub const struct_statx_timestamp = extern struct {
    tv_sec: __s64 = 0,
    tv_nsec: __u32 = 0,
    __reserved: __s32 = 0,
};
pub const struct_statx = extern struct {
    stx_mask: __u32 = 0,
    stx_blksize: __u32 = 0,
    stx_attributes: __u64 = 0,
    stx_nlink: __u32 = 0,
    stx_uid: __u32 = 0,
    stx_gid: __u32 = 0,
    stx_mode: __u16 = 0,
    __spare0: [1]__u16 = @import("std").mem.zeroes([1]__u16),
    stx_ino: __u64 = 0,
    stx_size: __u64 = 0,
    stx_blocks: __u64 = 0,
    stx_attributes_mask: __u64 = 0,
    stx_atime: struct_statx_timestamp = @import("std").mem.zeroes(struct_statx_timestamp),
    stx_btime: struct_statx_timestamp = @import("std").mem.zeroes(struct_statx_timestamp),
    stx_ctime: struct_statx_timestamp = @import("std").mem.zeroes(struct_statx_timestamp),
    stx_mtime: struct_statx_timestamp = @import("std").mem.zeroes(struct_statx_timestamp),
    stx_rdev_major: __u32 = 0,
    stx_rdev_minor: __u32 = 0,
    stx_dev_major: __u32 = 0,
    stx_dev_minor: __u32 = 0,
    stx_mnt_id: __u64 = 0,
    stx_dio_mem_align: __u32 = 0,
    stx_dio_offset_align: __u32 = 0,
    __spare3: [12]__u64 = @import("std").mem.zeroes([12]__u64),
};
pub extern fn statx(__dirfd: c_int, noalias __path: [*c]const u8, __flags: c_int, __mask: c_uint, noalias __buf: [*c]struct_statx) c_int;
pub extern fn Py_DecodeLocale(arg: [*c]const u8, size: [*c]usize) [*c]wchar_t;
pub extern fn Py_EncodeLocale(text: [*c]const wchar_t, error_pos: [*c]usize) [*c]u8;
pub extern fn Py_fopen(path: [*c]PyObject, mode: [*c]const u8) [*c]FILE;
pub fn _Py_fopen_obj(arg_path: [*c]PyObject, arg_mode: [*c]const u8) callconv(.c) [*c]FILE {
    var path = arg_path;
    _ = &path;
    var mode = arg_mode;
    _ = &mode;
    return Py_fopen(path, mode);
}
pub extern fn Py_fclose(file: [*c]FILE) c_int;
pub extern fn PyTraceMalloc_Track(domain: c_uint, ptr: usize, size: usize) c_int;
pub extern fn PyTraceMalloc_Untrack(domain: c_uint, ptr: usize) c_int;

pub const __VERSION__ = "Aro aro-zig";
pub const __Aro__ = "";
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const __STDC_EMBED_NOT_FOUND__ = @as(c_int, 0);
pub const __STDC_EMBED_FOUND__ = @as(c_int, 1);
pub const __STDC_EMBED_EMPTY__ = @as(c_int, 2);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __GNUC__ = @as(c_int, 7);
pub const __GNUC_MINOR__ = @as(c_int, 1);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 0);
pub const __ARO_EMULATE_NO__ = @as(c_int, 0);
pub const __ARO_EMULATE_CLANG__ = @as(c_int, 1);
pub const __ARO_EMULATE_GCC__ = @as(c_int, 2);
pub const __ARO_EMULATE_MSVC__ = @as(c_int, 3);
pub const __ARO_EMULATE__ = __ARO_EMULATE_GCC__;
pub inline fn __building_module(x: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &x;
    return @as(c_int, 0);
}
pub const __OPTIMIZE__ = @as(c_int, 1);
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`"); // <builtin>:34:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`"); // <builtin>:35:9
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __VAES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __VPCLMULQDQ__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MWAITX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __SSE4A__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __GFNI__ = @as(c_int, 1);
pub const __EVEX512__ = @as(c_int, 1);
pub const __AVX512CD__ = @as(c_int, 1);
pub const __AVX512VPOPCNTDQ__ = @as(c_int, 1);
pub const __AVX512VNNI__ = @as(c_int, 1);
pub const __AVX512BF16__ = @as(c_int, 1);
pub const __AVX512DQ__ = @as(c_int, 1);
pub const __AVX512BITALG__ = @as(c_int, 1);
pub const __AVX512BW__ = @as(c_int, 1);
pub const __AVX512VL__ = @as(c_int, 1);
pub const __EVEX256__ = @as(c_int, 1);
pub const __AVX512VBMI__ = @as(c_int, 1);
pub const __AVX512VBMI2__ = @as(c_int, 1);
pub const __AVX512IFMA__ = @as(c_int, 1);
pub const __AVX512VP2INTERSECT__ = @as(c_int, 1);
pub const __SHA__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __PKU__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __CLWB__ = @as(c_int, 1);
pub const __WBNOINVD__ = @as(c_int, 1);
pub const __SHSTK__ = @as(c_int, 1);
pub const __CLZERO__ = @as(c_int, 1);
pub const __RDPID__ = @as(c_int, 1);
pub const __RDPRU__ = @as(c_int, 1);
pub const __MOVDIRI__ = @as(c_int, 1);
pub const __MOVDIR64B__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __AVXVNNI__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX512F__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const __ELF__ = @as(c_int, 1);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __ATOMIC_BOOL_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_WINT_T_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_SHORT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_INT_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_LLONG_LOCK_FREE = @as(c_int, 1);
pub const __ATOMIC_POINTER_LOCK_FREE = @as(c_int, 1);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SCHAR_WIDTH__ = @as(c_int, 8);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __LONG_LONG_WIDTH__ = @as(c_int, 64);
pub const __WCHAR_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __WINT_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIG_ATOMIC_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __BITINT_MAXWIDTH__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 10);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_WINT_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTPTR_TYPE__ = c_long;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // <builtin>:176:9
pub const __INTMAX_C = __helpers.L_SUFFIX;
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // <builtin>:179:9
pub const __UINTMAX_C = __helpers.UL_SUFFIX;
pub const __PTRDIFF_TYPE__ = c_long;
pub const __SIZE_TYPE__ = c_ulong;
pub const __WCHAR_TYPE__ = c_int;
pub const __WINT_TYPE__ = c_uint;
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub inline fn __INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub inline fn __INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub inline fn __INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`"); // <builtin>:205:9
pub const __INT64_C = __helpers.L_SUFFIX;
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub inline fn __UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub inline fn __UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const __UINT16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`"); // <builtin>:230:9
pub const __UINT32_C = __helpers.U_SUFFIX;
pub const __UINT32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`"); // <builtin>:239:9
pub const __UINT64_C = __helpers.UL_SUFFIX;
pub const __UINT64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const INT_LEAST8_FMTd__ = "hhd";
pub const INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const UINT_LEAST8_FMTo__ = "hho";
pub const UINT_LEAST8_FMTu__ = "hhu";
pub const UINT_LEAST8_FMTx__ = "hhx";
pub const UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const INT_FAST8_FMTd__ = "hhd";
pub const INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const UINT_FAST8_FMTo__ = "hho";
pub const UINT_FAST8_FMTu__ = "hhu";
pub const UINT_FAST8_FMTx__ = "hhx";
pub const UINT_FAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const INT_LEAST16_FMTd__ = "hd";
pub const INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST16_FMTo__ = "ho";
pub const UINT_LEAST16_FMTu__ = "hu";
pub const UINT_LEAST16_FMTx__ = "hx";
pub const UINT_LEAST16_FMTX__ = "hX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const INT_FAST16_FMTd__ = "hd";
pub const INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_FAST16_FMTo__ = "ho";
pub const UINT_FAST16_FMTu__ = "hu";
pub const UINT_FAST16_FMTx__ = "hx";
pub const UINT_FAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const INT_LEAST32_FMTd__ = "d";
pub const INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST32_FMTo__ = "o";
pub const UINT_LEAST32_FMTu__ = "u";
pub const UINT_LEAST32_FMTx__ = "x";
pub const UINT_LEAST32_FMTX__ = "X";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const INT_FAST32_FMTd__ = "d";
pub const INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_FAST32_FMTo__ = "o";
pub const UINT_FAST32_FMTu__ = "u";
pub const UINT_FAST32_FMTx__ = "x";
pub const UINT_FAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const INT_LEAST64_FMTd__ = "ld";
pub const INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_LEAST64_FMTo__ = "lo";
pub const UINT_LEAST64_FMTu__ = "lu";
pub const UINT_LEAST64_FMTx__ = "lx";
pub const UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const INT_FAST64_FMTd__ = "ld";
pub const INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_FMTo__ = "lo";
pub const UINT_FAST64_FMTu__ = "lu";
pub const UINT_FAST64_FMTx__ = "lx";
pub const UINT_FAST64_FMTX__ = "lX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_HAS_DENORM__ = "";
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = "";
pub const __FLT16_HAS_QUIET_NAN__ = "";
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = "";
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = "";
pub const __FLT_HAS_QUIET_NAN__ = "";
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_HAS_DENORM__ = "";
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = "";
pub const __DBL_HAS_QUIET_NAN__ = "";
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = "";
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = "";
pub const __LDBL_HAS_QUIET_NAN__ = "";
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __FLT_EVAL_METHOD__ = @as(c_int, 0);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __pic__ = @as(c_int, 2);
pub const __PIC__ = @as(c_int, 2);
pub const NDEBUG = @as(c_int, 1);
pub const __GLIBC_MINOR__ = @as(c_int, 39);
pub const PY_SSIZE_T_CLEAN = "";
pub const Py_PYTHON_H = "";
pub const _Py_PATCHLEVEL_H = "";
pub const PY_RELEASE_LEVEL_ALPHA = @as(c_int, 0xA);
pub const PY_RELEASE_LEVEL_BETA = @as(c_int, 0xB);
pub const PY_RELEASE_LEVEL_GAMMA = @as(c_int, 0xC);
pub const PY_RELEASE_LEVEL_FINAL = @as(c_int, 0xF);
pub const PY_MAJOR_VERSION = @as(c_int, 3);
pub const PY_MINOR_VERSION = @as(c_int, 14);
pub const PY_MICRO_VERSION = @as(c_int, 2);
pub const PY_RELEASE_LEVEL = PY_RELEASE_LEVEL_FINAL;
pub const PY_RELEASE_SERIAL = @as(c_int, 0);
pub const PY_VERSION = "3.14.2";
pub inline fn _Py_PACK_FULL_VERSION(X: anytype, Y: anytype, Z: anytype, LEVEL: anytype, SERIAL: anytype) @TypeOf((((((X & @as(c_int, 0xff)) << @as(c_int, 24)) | ((Y & @as(c_int, 0xff)) << @as(c_int, 16))) | ((Z & @as(c_int, 0xff)) << @as(c_int, 8))) | ((LEVEL & @as(c_int, 0xf)) << @as(c_int, 4))) | ((SERIAL & @as(c_int, 0xf)) << @as(c_int, 0))) {
    _ = &X;
    _ = &Y;
    _ = &Z;
    _ = &LEVEL;
    _ = &SERIAL;
    return (((((X & @as(c_int, 0xff)) << @as(c_int, 24)) | ((Y & @as(c_int, 0xff)) << @as(c_int, 16))) | ((Z & @as(c_int, 0xff)) << @as(c_int, 8))) | ((LEVEL & @as(c_int, 0xf)) << @as(c_int, 4))) | ((SERIAL & @as(c_int, 0xf)) << @as(c_int, 0));
}
pub const PY_VERSION_HEX = _Py_PACK_FULL_VERSION(PY_MAJOR_VERSION, PY_MINOR_VERSION, PY_MICRO_VERSION, PY_RELEASE_LEVEL, PY_RELEASE_SERIAL);
pub const Py_PYCONFIG_H = "";
pub const ALIGNOF_LONG = @as(c_int, 8);
pub const ALIGNOF_MAX_ALIGN_T = @as(c_int, 16);
pub const ALIGNOF_SIZE_T = @as(c_int, 8);
pub const DOUBLE_IS_LITTLE_ENDIAN_IEEE754 = @as(c_int, 1);
pub const ENABLE_IPV6 = @as(c_int, 1);
pub const HAVE_ACCEPT = @as(c_int, 1);
pub const HAVE_ACCEPT4 = @as(c_int, 1);
pub const HAVE_ACOSH = @as(c_int, 1);
pub const HAVE_ADDRINFO = @as(c_int, 1);
pub const HAVE_ALARM = @as(c_int, 1);
pub const HAVE_ALLOCA_H = @as(c_int, 1);
pub const HAVE_ASINH = @as(c_int, 1);
pub const HAVE_ASM_TYPES_H = @as(c_int, 1);
pub const HAVE_ATANH = @as(c_int, 1);
pub const HAVE_BACKTRACE = @as(c_int, 1);
pub const HAVE_BIND = @as(c_int, 1);
pub const HAVE_BIND_TEXTDOMAIN_CODESET = @as(c_int, 1);
pub const HAVE_BLUETOOTH_BLUETOOTH_H = @as(c_int, 1);
pub const HAVE_BUILTIN_ATOMIC = @as(c_int, 1);
pub const HAVE_BZLIB_H = @as(c_int, 1);
pub const HAVE_CHMOD = @as(c_int, 1);
pub const HAVE_CHOWN = @as(c_int, 1);
pub const HAVE_CHROOT = @as(c_int, 1);
pub const HAVE_CLOCK = @as(c_int, 1);
pub const HAVE_CLOCK_GETRES = @as(c_int, 1);
pub const HAVE_CLOCK_GETTIME = @as(c_int, 1);
pub const HAVE_CLOCK_NANOSLEEP = @as(c_int, 1);
pub const HAVE_CLOCK_SETTIME = @as(c_int, 1);
pub const HAVE_CLOCK_T = @as(c_int, 1);
pub const HAVE_CLOSEFROM = @as(c_int, 1);
pub const HAVE_CLOSE_RANGE = @as(c_int, 1);
pub const HAVE_COMPUTED_GOTOS = @as(c_int, 1);
pub const HAVE_CONFSTR = @as(c_int, 1);
pub const HAVE_CONNECT = @as(c_int, 1);
pub const HAVE_COPY_FILE_RANGE = @as(c_int, 1);
pub const HAVE_CTERMID = @as(c_int, 1);
pub const HAVE_CURSES_FILTER = @as(c_int, 1);
pub const HAVE_CURSES_H = @as(c_int, 1);
pub const HAVE_CURSES_HAS_KEY = @as(c_int, 1);
pub const HAVE_CURSES_IMMEDOK = @as(c_int, 1);
pub const HAVE_CURSES_IS_PAD = @as(c_int, 1);
pub const HAVE_CURSES_IS_TERM_RESIZED = @as(c_int, 1);
pub const HAVE_CURSES_RESIZETERM = @as(c_int, 1);
pub const HAVE_CURSES_RESIZE_TERM = @as(c_int, 1);
pub const HAVE_CURSES_SYNCOK = @as(c_int, 1);
pub const HAVE_CURSES_TYPEAHEAD = @as(c_int, 1);
pub const HAVE_CURSES_USE_ENV = @as(c_int, 1);
pub const HAVE_CURSES_WCHGAT = @as(c_int, 1);
pub const HAVE_DB_H = @as(c_int, 1);
pub const HAVE_DECL_RTLD_DEEPBIND = @as(c_int, 1);
pub const HAVE_DECL_RTLD_GLOBAL = @as(c_int, 1);
pub const HAVE_DECL_RTLD_LAZY = @as(c_int, 1);
pub const HAVE_DECL_RTLD_LOCAL = @as(c_int, 1);
pub const HAVE_DECL_RTLD_MEMBER = @as(c_int, 0);
pub const HAVE_DECL_RTLD_NODELETE = @as(c_int, 1);
pub const HAVE_DECL_RTLD_NOLOAD = @as(c_int, 1);
pub const HAVE_DECL_RTLD_NOW = @as(c_int, 1);
pub const HAVE_DECL_UT_NAMESIZE = @as(c_int, 1);
pub const HAVE_DEVICE_MACROS = @as(c_int, 1);
pub const HAVE_DEV_PTMX = @as(c_int, 1);
pub const HAVE_DIRENT_D_TYPE = @as(c_int, 1);
pub const HAVE_DIRENT_H = @as(c_int, 1);
pub const HAVE_DIRFD = @as(c_int, 1);
pub const HAVE_DLADDR = @as(c_int, 1);
pub const HAVE_DLADDR1 = @as(c_int, 1);
pub const HAVE_DLFCN_H = @as(c_int, 1);
pub const HAVE_DLOPEN = @as(c_int, 1);
pub const HAVE_DUP = @as(c_int, 1);
pub const HAVE_DUP2 = @as(c_int, 1);
pub const HAVE_DUP3 = @as(c_int, 1);
pub const HAVE_DYNAMIC_LOADING = @as(c_int, 1);
pub const HAVE_ENDIAN_H = @as(c_int, 1);
pub const HAVE_EPOLL = @as(c_int, 1);
pub const HAVE_EPOLL_CREATE1 = @as(c_int, 1);
pub const HAVE_ERF = @as(c_int, 1);
pub const HAVE_ERFC = @as(c_int, 1);
pub const HAVE_ERRNO_H = @as(c_int, 1);
pub const HAVE_EVENTFD = @as(c_int, 1);
pub const HAVE_EXECINFO_H = @as(c_int, 1);
pub const HAVE_EXECV = @as(c_int, 1);
pub const HAVE_EXPLICIT_BZERO = @as(c_int, 1);
pub const HAVE_EXPM1 = @as(c_int, 1);
pub const HAVE_FACCESSAT = @as(c_int, 1);
pub const HAVE_FCHDIR = @as(c_int, 1);
pub const HAVE_FCHMOD = @as(c_int, 1);
pub const HAVE_FCHMODAT = @as(c_int, 1);
pub const HAVE_FCHOWN = @as(c_int, 1);
pub const HAVE_FCHOWNAT = @as(c_int, 1);
pub const HAVE_FCNTL_H = @as(c_int, 1);
pub const HAVE_FDATASYNC = @as(c_int, 1);
pub const HAVE_FDOPENDIR = @as(c_int, 1);
pub const HAVE_FEXECVE = @as(c_int, 1);
pub const HAVE_FFI_CLOSURE_ALLOC = @as(c_int, 1);
pub const HAVE_FFI_PREP_CIF_VAR = @as(c_int, 1);
pub const HAVE_FFI_PREP_CLOSURE_LOC = @as(c_int, 1);
pub const HAVE_FLOCK = @as(c_int, 1);
pub const HAVE_FORK = @as(c_int, 1);
pub const HAVE_FORKPTY = @as(c_int, 1);
pub const HAVE_FPATHCONF = @as(c_int, 1);
pub const HAVE_FSEEKO = @as(c_int, 1);
pub const HAVE_FSTATAT = @as(c_int, 1);
pub const HAVE_FSTATVFS = @as(c_int, 1);
pub const HAVE_FSYNC = @as(c_int, 1);
pub const HAVE_FTELLO = @as(c_int, 1);
pub const HAVE_FTIME = @as(c_int, 1);
pub const HAVE_FTRUNCATE = @as(c_int, 1);
pub const HAVE_FUTIMENS = @as(c_int, 1);
pub const HAVE_FUTIMES = @as(c_int, 1);
pub const HAVE_FUTIMESAT = @as(c_int, 1);
pub const HAVE_GAI_STRERROR = @as(c_int, 1);
pub const HAVE_GCC_ASM_FOR_X64 = @as(c_int, 1);
pub const HAVE_GCC_ASM_FOR_X87 = @as(c_int, 1);
pub const HAVE_GCC_UINT128_T = @as(c_int, 1);
pub const HAVE_GDBM_H = @as(c_int, 1);
pub const HAVE_GETADDRINFO = @as(c_int, 1);
pub const HAVE_GETC_UNLOCKED = @as(c_int, 1);
pub const HAVE_GETEGID = @as(c_int, 1);
pub const HAVE_GETENTROPY = @as(c_int, 1);
pub const HAVE_GETEUID = @as(c_int, 1);
pub const HAVE_GETGID = @as(c_int, 1);
pub const HAVE_GETGRENT = @as(c_int, 1);
pub const HAVE_GETGRGID = @as(c_int, 1);
pub const HAVE_GETGRGID_R = @as(c_int, 1);
pub const HAVE_GETGRNAM_R = @as(c_int, 1);
pub const HAVE_GETGROUPLIST = @as(c_int, 1);
pub const HAVE_GETGROUPS = @as(c_int, 1);
pub const HAVE_GETHOSTBYADDR = @as(c_int, 1);
pub const HAVE_GETHOSTBYNAME = @as(c_int, 1);
pub const HAVE_GETHOSTBYNAME_R = @as(c_int, 1);
pub const HAVE_GETHOSTBYNAME_R_6_ARG = @as(c_int, 1);
pub const HAVE_GETHOSTNAME = @as(c_int, 1);
pub const HAVE_GETITIMER = @as(c_int, 1);
pub const HAVE_GETLOADAVG = @as(c_int, 1);
pub const HAVE_GETLOGIN = @as(c_int, 1);
pub const HAVE_GETLOGIN_R = @as(c_int, 1);
pub const HAVE_GETNAMEINFO = @as(c_int, 1);
pub const HAVE_GETPAGESIZE = @as(c_int, 1);
pub const HAVE_GETPEERNAME = @as(c_int, 1);
pub const HAVE_GETPGID = @as(c_int, 1);
pub const HAVE_GETPGRP = @as(c_int, 1);
pub const HAVE_GETPID = @as(c_int, 1);
pub const HAVE_GETPPID = @as(c_int, 1);
pub const HAVE_GETPRIORITY = @as(c_int, 1);
pub const HAVE_GETPROTOBYNAME = @as(c_int, 1);
pub const HAVE_GETPWENT = @as(c_int, 1);
pub const HAVE_GETPWNAM_R = @as(c_int, 1);
pub const HAVE_GETPWUID = @as(c_int, 1);
pub const HAVE_GETPWUID_R = @as(c_int, 1);
pub const HAVE_GETRANDOM = @as(c_int, 1);
pub const HAVE_GETRANDOM_SYSCALL = @as(c_int, 1);
pub const HAVE_GETRESGID = @as(c_int, 1);
pub const HAVE_GETRESUID = @as(c_int, 1);
pub const HAVE_GETRUSAGE = @as(c_int, 1);
pub const HAVE_GETSERVBYNAME = @as(c_int, 1);
pub const HAVE_GETSERVBYPORT = @as(c_int, 1);
pub const HAVE_GETSID = @as(c_int, 1);
pub const HAVE_GETSOCKNAME = @as(c_int, 1);
pub const HAVE_GETSPENT = @as(c_int, 1);
pub const HAVE_GETSPNAM = @as(c_int, 1);
pub const HAVE_GETUID = @as(c_int, 1);
pub const HAVE_GETWD = @as(c_int, 1);
pub const HAVE_GRANTPT = @as(c_int, 1);
pub const HAVE_GRP_H = @as(c_int, 1);
pub const HAVE_HSTRERROR = @as(c_int, 1);
pub const HAVE_HTOLE64 = @as(c_int, 1);
pub const HAVE_IF_NAMEINDEX = @as(c_int, 1);
pub const HAVE_INET_ATON = @as(c_int, 1);
pub const HAVE_INET_NTOA = @as(c_int, 1);
pub const HAVE_INET_PTON = @as(c_int, 1);
pub const HAVE_INITGROUPS = @as(c_int, 1);
pub const HAVE_INTTYPES_H = @as(c_int, 1);
pub const HAVE_KILL = @as(c_int, 1);
pub const HAVE_KILLPG = @as(c_int, 1);
pub const HAVE_LANGINFO_H = @as(c_int, 1);
pub const HAVE_LCHOWN = @as(c_int, 1);
pub const HAVE_LIBDB = @as(c_int, 1);
pub const HAVE_LIBDL = @as(c_int, 1);
pub const HAVE_LIBINTL_H = @as(c_int, 1);
pub const HAVE_LIBSQLITE3 = @as(c_int, 1);
pub const HAVE_LINK = @as(c_int, 1);
pub const HAVE_LINKAT = @as(c_int, 1);
pub const HAVE_LINK_H = @as(c_int, 1);
pub const HAVE_LINUX_AUXVEC_H = @as(c_int, 1);
pub const HAVE_LINUX_CAN_BCM_H = @as(c_int, 1);
pub const HAVE_LINUX_CAN_H = @as(c_int, 1);
pub const HAVE_LINUX_CAN_J1939_H = @as(c_int, 1);
pub const HAVE_LINUX_CAN_RAW_FD_FRAMES = @as(c_int, 1);
pub const HAVE_LINUX_CAN_RAW_H = @as(c_int, 1);
pub const HAVE_LINUX_CAN_RAW_JOIN_FILTERS = @as(c_int, 1);
pub const HAVE_LINUX_FS_H = @as(c_int, 1);
pub const HAVE_LINUX_LIMITS_H = @as(c_int, 1);
pub const HAVE_LINUX_MEMFD_H = @as(c_int, 1);
pub const HAVE_LINUX_NETFILTER_IPV4_H = @as(c_int, 1);
pub const HAVE_LINUX_NETLINK_H = @as(c_int, 1);
pub const HAVE_LINUX_QRTR_H = @as(c_int, 1);
pub const HAVE_LINUX_RANDOM_H = @as(c_int, 1);
pub const HAVE_LINUX_SCHED_H = @as(c_int, 1);
pub const HAVE_LINUX_SOUNDCARD_H = @as(c_int, 1);
pub const HAVE_LINUX_TIPC_H = @as(c_int, 1);
pub const HAVE_LINUX_VM_SOCKETS_H = @as(c_int, 1);
pub const HAVE_LINUX_WAIT_H = @as(c_int, 1);
pub const HAVE_LISTEN = @as(c_int, 1);
pub const HAVE_LOCKF = @as(c_int, 1);
pub const HAVE_LOG1P = @as(c_int, 1);
pub const HAVE_LOG2 = @as(c_int, 1);
pub const HAVE_LOGIN_TTY = @as(c_int, 1);
pub const HAVE_LONG_DOUBLE = @as(c_int, 1);
pub const HAVE_LSTAT = @as(c_int, 1);
pub const HAVE_LUTIMES = @as(c_int, 1);
pub const HAVE_MADVISE = @as(c_int, 1);
pub const HAVE_MAKEDEV = @as(c_int, 1);
pub const HAVE_MBRTOWC = @as(c_int, 1);
pub const HAVE_MEMFD_CREATE = @as(c_int, 1);
pub const HAVE_MEMRCHR = @as(c_int, 1);
pub const HAVE_MKDIRAT = @as(c_int, 1);
pub const HAVE_MKFIFO = @as(c_int, 1);
pub const HAVE_MKFIFOAT = @as(c_int, 1);
pub const HAVE_MKNOD = @as(c_int, 1);
pub const HAVE_MKNODAT = @as(c_int, 1);
pub const HAVE_MKTIME = @as(c_int, 1);
pub const HAVE_MMAP = @as(c_int, 1);
pub const HAVE_MREMAP = @as(c_int, 1);
pub const HAVE_NANOSLEEP = @as(c_int, 1);
pub const HAVE_NCURSESW = @as(c_int, 1);
pub const HAVE_NCURSESW_CURSES_H = @as(c_int, 1);
pub const HAVE_NCURSESW_NCURSES_H = @as(c_int, 1);
pub const HAVE_NCURSESW_PANEL_H = @as(c_int, 1);
pub const HAVE_NCURSES_H = @as(c_int, 1);
pub const HAVE_NETDB_H = @as(c_int, 1);
pub const HAVE_NETINET_IN_H = @as(c_int, 1);
pub const HAVE_NETPACKET_PACKET_H = @as(c_int, 1);
pub const HAVE_NET_ETHERNET_H = @as(c_int, 1);
pub const HAVE_NET_IF_H = @as(c_int, 1);
pub const HAVE_NICE = @as(c_int, 1);
pub const HAVE_OPENAT = @as(c_int, 1);
pub const HAVE_OPENDIR = @as(c_int, 1);
pub const HAVE_OPENPTY = @as(c_int, 1);
pub const HAVE_PANELW = @as(c_int, 1);
pub const HAVE_PANEL_H = @as(c_int, 1);
pub const HAVE_PATHCONF = @as(c_int, 1);
pub const HAVE_PAUSE = @as(c_int, 1);
pub const HAVE_PIPE = @as(c_int, 1);
pub const HAVE_PIPE2 = @as(c_int, 1);
pub const HAVE_POLL = @as(c_int, 1);
pub const HAVE_POLL_H = @as(c_int, 1);
pub const HAVE_POSIX_FADVISE = @as(c_int, 1);
pub const HAVE_POSIX_FALLOCATE = @as(c_int, 1);
pub const HAVE_POSIX_OPENPT = @as(c_int, 1);
pub const HAVE_POSIX_SPAWN = @as(c_int, 1);
pub const HAVE_POSIX_SPAWNP = @as(c_int, 1);
pub const HAVE_POSIX_SPAWN_FILE_ACTIONS_ADDCLOSEFROM_NP = @as(c_int, 1);
pub const HAVE_PREAD = @as(c_int, 1);
pub const HAVE_PREADV = @as(c_int, 1);
pub const HAVE_PREADV2 = @as(c_int, 1);
pub const HAVE_PRLIMIT = @as(c_int, 1);
pub const HAVE_PROCESS_VM_READV = @as(c_int, 1);
pub const HAVE_PROTOTYPES = @as(c_int, 1);
pub const HAVE_PTHREAD_CONDATTR_SETCLOCK = @as(c_int, 1);
pub const HAVE_PTHREAD_GETATTR_NP = @as(c_int, 1);
pub const HAVE_PTHREAD_GETCPUCLOCKID = @as(c_int, 1);
pub const HAVE_PTHREAD_GETNAME_NP = @as(c_int, 1);
pub const HAVE_PTHREAD_H = @as(c_int, 1);
pub const HAVE_PTHREAD_KILL = @as(c_int, 1);
pub const HAVE_PTHREAD_SETNAME_NP = @as(c_int, 1);
pub const HAVE_PTHREAD_SIGMASK = @as(c_int, 1);
pub const HAVE_PTSNAME = @as(c_int, 1);
pub const HAVE_PTSNAME_R = @as(c_int, 1);
pub const HAVE_PTY_H = @as(c_int, 1);
pub const HAVE_PWRITE = @as(c_int, 1);
pub const HAVE_PWRITEV = @as(c_int, 1);
pub const HAVE_PWRITEV2 = @as(c_int, 1);
pub const HAVE_READLINK = @as(c_int, 1);
pub const HAVE_READLINKAT = @as(c_int, 1);
pub const HAVE_READV = @as(c_int, 1);
pub const HAVE_REALPATH = @as(c_int, 1);
pub const HAVE_RECVFROM = @as(c_int, 1);
pub const HAVE_RENAMEAT = @as(c_int, 1);
pub const HAVE_RL_APPEND_HISTORY = @as(c_int, 1);
pub const HAVE_RL_CATCH_SIGNAL = @as(c_int, 1);
pub const HAVE_RL_COMPDISP_FUNC_T = @as(c_int, 1);
pub const HAVE_RL_COMPLETION_APPEND_CHARACTER = @as(c_int, 1);
pub const HAVE_RL_COMPLETION_DISPLAY_MATCHES_HOOK = @as(c_int, 1);
pub const HAVE_RL_COMPLETION_MATCHES = @as(c_int, 1);
pub const HAVE_RL_COMPLETION_SUPPRESS_APPEND = @as(c_int, 1);
pub const HAVE_RL_PRE_INPUT_HOOK = @as(c_int, 1);
pub const HAVE_RL_RESIZE_TERMINAL = @as(c_int, 1);
pub const HAVE_SCHED_GET_PRIORITY_MAX = @as(c_int, 1);
pub const HAVE_SCHED_H = @as(c_int, 1);
pub const HAVE_SCHED_RR_GET_INTERVAL = @as(c_int, 1);
pub const HAVE_SCHED_SETAFFINITY = @as(c_int, 1);
pub const HAVE_SCHED_SETPARAM = @as(c_int, 1);
pub const HAVE_SCHED_SETSCHEDULER = @as(c_int, 1);
pub const HAVE_SEM_CLOCKWAIT = @as(c_int, 1);
pub const HAVE_SEM_GETVALUE = @as(c_int, 1);
pub const HAVE_SEM_OPEN = @as(c_int, 1);
pub const HAVE_SEM_TIMEDWAIT = @as(c_int, 1);
pub const HAVE_SEM_UNLINK = @as(c_int, 1);
pub const HAVE_SENDFILE = @as(c_int, 1);
pub const HAVE_SENDTO = @as(c_int, 1);
pub const HAVE_SETEGID = @as(c_int, 1);
pub const HAVE_SETEUID = @as(c_int, 1);
pub const HAVE_SETGID = @as(c_int, 1);
pub const HAVE_SETGROUPS = @as(c_int, 1);
pub const HAVE_SETHOSTNAME = @as(c_int, 1);
pub const HAVE_SETITIMER = @as(c_int, 1);
pub const HAVE_SETJMP_H = @as(c_int, 1);
pub const HAVE_SETLOCALE = @as(c_int, 1);
pub const HAVE_SETNS = @as(c_int, 1);
pub const HAVE_SETPGID = @as(c_int, 1);
pub const HAVE_SETPGRP = @as(c_int, 1);
pub const HAVE_SETPRIORITY = @as(c_int, 1);
pub const HAVE_SETREGID = @as(c_int, 1);
pub const HAVE_SETRESGID = @as(c_int, 1);
pub const HAVE_SETRESUID = @as(c_int, 1);
pub const HAVE_SETREUID = @as(c_int, 1);
pub const HAVE_SETSID = @as(c_int, 1);
pub const HAVE_SETSOCKOPT = @as(c_int, 1);
pub const HAVE_SETUID = @as(c_int, 1);
pub const HAVE_SETVBUF = @as(c_int, 1);
pub const HAVE_SHADOW_H = @as(c_int, 1);
pub const HAVE_SHM_OPEN = @as(c_int, 1);
pub const HAVE_SHM_UNLINK = @as(c_int, 1);
pub const HAVE_SHUTDOWN = @as(c_int, 1);
pub const HAVE_SIGACTION = @as(c_int, 1);
pub const HAVE_SIGALTSTACK = @as(c_int, 1);
pub const HAVE_SIGFILLSET = @as(c_int, 1);
pub const HAVE_SIGINFO_T_SI_BAND = @as(c_int, 1);
pub const HAVE_SIGINTERRUPT = @as(c_int, 1);
pub const HAVE_SIGNAL_H = @as(c_int, 1);
pub const HAVE_SIGPENDING = @as(c_int, 1);
pub const HAVE_SIGRELSE = @as(c_int, 1);
pub const HAVE_SIGTIMEDWAIT = @as(c_int, 1);
pub const HAVE_SIGWAIT = @as(c_int, 1);
pub const HAVE_SIGWAITINFO = @as(c_int, 1);
pub const HAVE_SNPRINTF = @as(c_int, 1);
pub const HAVE_SOCKADDR_ALG = @as(c_int, 1);
pub const HAVE_SOCKADDR_STORAGE = @as(c_int, 1);
pub const HAVE_SOCKET = @as(c_int, 1);
pub const HAVE_SOCKETPAIR = @as(c_int, 1);
pub const HAVE_SOCKLEN_T = @as(c_int, 1);
pub const HAVE_SPAWN_H = @as(c_int, 1);
pub const HAVE_SPLICE = @as(c_int, 1);
pub const HAVE_SSIZE_T = @as(c_int, 1);
pub const HAVE_STATVFS = @as(c_int, 1);
pub const HAVE_STAT_TV_NSEC = @as(c_int, 1);
pub const HAVE_STDINT_H = @as(c_int, 1);
pub const HAVE_STDIO_H = @as(c_int, 1);
pub const HAVE_STDLIB_H = @as(c_int, 1);
pub const HAVE_STD_ATOMIC = @as(c_int, 1);
pub const HAVE_STRFTIME = @as(c_int, 1);
pub const HAVE_STRINGS_H = @as(c_int, 1);
pub const HAVE_STRING_H = @as(c_int, 1);
pub const HAVE_STRLCPY = @as(c_int, 1);
pub const HAVE_STRSIGNAL = @as(c_int, 1);
pub const HAVE_STRUCT_PASSWD_PW_GECOS = @as(c_int, 1);
pub const HAVE_STRUCT_PASSWD_PW_PASSWD = @as(c_int, 1);
pub const HAVE_STRUCT_STAT_ST_BLKSIZE = @as(c_int, 1);
pub const HAVE_STRUCT_STAT_ST_BLOCKS = @as(c_int, 1);
pub const HAVE_STRUCT_STAT_ST_RDEV = @as(c_int, 1);
pub const HAVE_STRUCT_TM_TM_ZONE = @as(c_int, 1);
pub const HAVE_SYMLINK = @as(c_int, 1);
pub const HAVE_SYMLINKAT = @as(c_int, 1);
pub const HAVE_SYNC = @as(c_int, 1);
pub const HAVE_SYSCONF = @as(c_int, 1);
pub const HAVE_SYSEXITS_H = @as(c_int, 1);
pub const HAVE_SYSLOG_H = @as(c_int, 1);
pub const HAVE_SYSTEM = @as(c_int, 1);
pub const HAVE_SYS_AUXV_H = @as(c_int, 1);
pub const HAVE_SYS_EPOLL_H = @as(c_int, 1);
pub const HAVE_SYS_EVENTFD_H = @as(c_int, 1);
pub const HAVE_SYS_FILE_H = @as(c_int, 1);
pub const HAVE_SYS_IOCTL_H = @as(c_int, 1);
pub const HAVE_SYS_MMAN_H = @as(c_int, 1);
pub const HAVE_SYS_PARAM_H = @as(c_int, 1);
pub const HAVE_SYS_PIDFD_H = @as(c_int, 1);
pub const HAVE_SYS_POLL_H = @as(c_int, 1);
pub const HAVE_SYS_RANDOM_H = @as(c_int, 1);
pub const HAVE_SYS_RESOURCE_H = @as(c_int, 1);
pub const HAVE_SYS_SELECT_H = @as(c_int, 1);
pub const HAVE_SYS_SENDFILE_H = @as(c_int, 1);
pub const HAVE_SYS_SOCKET_H = @as(c_int, 1);
pub const HAVE_SYS_SOUNDCARD_H = @as(c_int, 1);
pub const HAVE_SYS_STATVFS_H = @as(c_int, 1);
pub const HAVE_SYS_STAT_H = @as(c_int, 1);
pub const HAVE_SYS_SYSCALL_H = @as(c_int, 1);
pub const HAVE_SYS_SYSMACROS_H = @as(c_int, 1);
pub const HAVE_SYS_TIMERFD_H = @as(c_int, 1);
pub const HAVE_SYS_TIMES_H = @as(c_int, 1);
pub const HAVE_SYS_TIME_H = @as(c_int, 1);
pub const HAVE_SYS_TYPES_H = @as(c_int, 1);
pub const HAVE_SYS_UIO_H = @as(c_int, 1);
pub const HAVE_SYS_UN_H = @as(c_int, 1);
pub const HAVE_SYS_UTSNAME_H = @as(c_int, 1);
pub const HAVE_SYS_WAIT_H = @as(c_int, 1);
pub const HAVE_SYS_XATTR_H = @as(c_int, 1);
pub const HAVE_TCGETPGRP = @as(c_int, 1);
pub const HAVE_TCSETPGRP = @as(c_int, 1);
pub const HAVE_TEMPNAM = @as(c_int, 1);
pub const HAVE_TERMIOS_H = @as(c_int, 1);
pub const HAVE_TERM_H = @as(c_int, 1);
pub const HAVE_TIMEGM = @as(c_int, 1);
pub const HAVE_TIMERFD_CREATE = @as(c_int, 1);
pub const HAVE_TIMES = @as(c_int, 1);
pub const HAVE_TMPFILE = @as(c_int, 1);
pub const HAVE_TMPNAM = @as(c_int, 1);
pub const HAVE_TMPNAM_R = @as(c_int, 1);
pub const HAVE_TM_ZONE = @as(c_int, 1);
pub const HAVE_TRUNCATE = @as(c_int, 1);
pub const HAVE_TTYNAME_R = @as(c_int, 1);
pub const HAVE_UMASK = @as(c_int, 1);
pub const HAVE_UNAME = @as(c_int, 1);
pub const HAVE_UNISTD_H = @as(c_int, 1);
pub const HAVE_UNLINKAT = @as(c_int, 1);
pub const HAVE_UNLOCKPT = @as(c_int, 1);
pub const HAVE_UNSHARE = @as(c_int, 1);
pub const HAVE_UTIMENSAT = @as(c_int, 1);
pub const HAVE_UTIMES = @as(c_int, 1);
pub const HAVE_UTIME_H = @as(c_int, 1);
pub const HAVE_UTMP_H = @as(c_int, 1);
pub const HAVE_UT_NAMESIZE = @as(c_int, 1);
pub const HAVE_UUID_GENERATE_TIME_SAFE = @as(c_int, 1);
pub const HAVE_UUID_H = @as(c_int, 1);
pub const HAVE_VFORK = @as(c_int, 1);
pub const HAVE_WAIT = @as(c_int, 1);
pub const HAVE_WAIT3 = @as(c_int, 1);
pub const HAVE_WAIT4 = @as(c_int, 1);
pub const HAVE_WAITID = @as(c_int, 1);
pub const HAVE_WAITPID = @as(c_int, 1);
pub const HAVE_WCHAR_H = @as(c_int, 1);
pub const HAVE_WCSCOLL = @as(c_int, 1);
pub const HAVE_WCSFTIME = @as(c_int, 1);
pub const HAVE_WCSXFRM = @as(c_int, 1);
pub const HAVE_WMEMCMP = @as(c_int, 1);
pub const HAVE_WORKING_TZSET = @as(c_int, 1);
pub const HAVE_WRITEV = @as(c_int, 1);
pub const HAVE_ZLIB_COPY = @as(c_int, 1);
pub const HAVE___UINT128_T = @as(c_int, 1);
pub const MAJOR_IN_SYSMACROS = @as(c_int, 1);
pub const MVWDELCH_IS_EXPRESSION = @as(c_int, 1);
pub const PTHREAD_KEY_T_IS_COMPATIBLE_WITH_INT = @as(c_int, 1);
pub const PTHREAD_SYSTEM_SCHED_SUPPORTED = @as(c_int, 1);
pub const PY_BUILTIN_HASHLIB_HASHES = "md5,sha1,sha2,sha3,blake2";
pub const PY_COERCE_C_LOCALE = @as(c_int, 1);
pub const PY_HAVE_PERF_TRAMPOLINE = @as(c_int, 1);
pub const PY_SQLITE_ENABLE_LOAD_EXTENSION = @as(c_int, 1);
pub const PY_SQLITE_HAVE_SERIALIZE = @as(c_int, 1);
pub const PY_SSL_DEFAULT_CIPHERS = @as(c_int, 1);
pub const PY_SUPPORT_TIER = @as(c_int, 1);
pub const Py_REMOTE_DEBUG = @as(c_int, 1);
pub const Py_RL_STARTUP_HOOK_TAKES_ARGS = @as(c_int, 1);
pub const RETSIGTYPE = anyopaque;
pub const SIZEOF_DOUBLE = @as(c_int, 8);
pub const SIZEOF_FLOAT = @as(c_int, 4);
pub const SIZEOF_FPOS_T = @as(c_int, 16);
pub const SIZEOF_INT = @as(c_int, 4);
pub const SIZEOF_LONG = @as(c_int, 8);
pub const SIZEOF_LONG_DOUBLE = @as(c_int, 16);
pub const SIZEOF_LONG_LONG = @as(c_int, 8);
pub const SIZEOF_OFF_T = @as(c_int, 8);
pub const SIZEOF_PID_T = @as(c_int, 4);
pub const SIZEOF_PTHREAD_KEY_T = @as(c_int, 4);
pub const SIZEOF_PTHREAD_T = @as(c_int, 8);
pub const SIZEOF_SHORT = @as(c_int, 2);
pub const SIZEOF_SIZE_T = @as(c_int, 8);
pub const SIZEOF_TIME_T = @as(c_int, 8);
pub const SIZEOF_UINTPTR_T = @as(c_int, 8);
pub const SIZEOF_VOID_P = @as(c_int, 8);
pub const SIZEOF_WCHAR_T = @as(c_int, 4);
pub const SIZEOF__BOOL = @as(c_int, 1);
pub const STDC_HEADERS = @as(c_int, 1);
pub const SYS_SELECT_WITH_SYS_TIME = @as(c_int, 1);
pub const USE_COMPUTED_GOTOS = @as(c_int, 1);
pub const _ALL_SOURCE = @as(c_int, 1);
pub const _DARWIN_C_SOURCE = @as(c_int, 1);
pub const __EXTENSIONS__ = @as(c_int, 1);
pub const _GNU_SOURCE = @as(c_int, 1);
pub const _HPUX_ALT_XOPEN_SOCKET_API = @as(c_int, 1);
pub const _NETBSD_SOURCE = @as(c_int, 1);
pub const _OPENBSD_SOURCE = @as(c_int, 1);
pub const _POSIX_PTHREAD_SEMANTICS = @as(c_int, 1);
pub const __STDC_WANT_IEC_60559_ATTRIBS_EXT__ = @as(c_int, 1);
pub const __STDC_WANT_IEC_60559_BFP_EXT__ = @as(c_int, 1);
pub const __STDC_WANT_IEC_60559_DFP_EXT__ = @as(c_int, 1);
pub const __STDC_WANT_IEC_60559_FUNCS_EXT__ = @as(c_int, 1);
pub const __STDC_WANT_IEC_60559_TYPES_EXT__ = @as(c_int, 1);
pub const __STDC_WANT_LIB_EXT2__ = @as(c_int, 1);
pub const __STDC_WANT_MATH_SPEC_FUNCS__ = @as(c_int, 1);
pub const _TANDEM_SOURCE = @as(c_int, 1);
pub const WITH_DECIMAL_CONTEXTVAR = @as(c_int, 1);
pub const WITH_DOC_STRINGS = @as(c_int, 1);
pub const WITH_MIMALLOC = @as(c_int, 1);
pub const WITH_PYMALLOC = @as(c_int, 1);
pub const _FILE_OFFSET_BITS = @as(c_int, 64);
pub const _PYTHONFRAMEWORK = "";
pub const _PYTHREAD_NAME_MAXLEN = @as(c_int, 15);
pub const _Py_FFI_SUPPORT_C_COMPLEX = @as(c_int, 1);
pub const _Py_HACL_CAN_COMPILE_VEC128 = @as(c_int, 1);
pub const _Py_HACL_CAN_COMPILE_VEC256 = @as(c_int, 1);
pub const _Py_STACK_GROWS_DOWN = @as(c_int, 1);
pub const _REENTRANT = @as(c_int, 1);
pub const __BSD_VISIBLE = @as(c_int, 1);
pub const PY_MACCONFIG_H = "";
pub const _ASSERT_H = @as(c_int, 1);
pub const _FEATURES_H = @as(c_int, 1);
pub const __KERNEL_STRICT_NAMES = "";
pub inline fn __GNUC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub inline fn __glibc_clang_prereq(maj: anytype, min: anytype) @TypeOf(@as(c_int, 0)) {
    _ = &maj;
    _ = &min;
    return @as(c_int, 0);
}
pub const __GLIBC_USE = @compileError("unable to translate macro: undefined identifier `__GLIBC_USE_`"); // /usr/include/features.h:188:9
pub const _ISOC95_SOURCE = @as(c_int, 1);
pub const _ISOC99_SOURCE = @as(c_int, 1);
pub const _ISOC11_SOURCE = @as(c_int, 1);
pub const _ISOC2X_SOURCE = @as(c_int, 1);
pub const _XOPEN_SOURCE = @as(c_int, 700);
pub const _XOPEN_SOURCE_EXTENDED = @as(c_int, 1);
pub const _LARGEFILE64_SOURCE = @as(c_int, 1);
pub const _DYNAMIC_STACK_SIZE_SOURCE = @as(c_int, 1);
pub const _DEFAULT_SOURCE = @as(c_int, 1);
pub const __GLIBC_USE_ISOC2X = @as(c_int, 1);
pub const __USE_ISOC11 = @as(c_int, 1);
pub const _POSIX_SOURCE = @as(c_int, 1);
pub const _POSIX_C_SOURCE = @as(c_long, 200809);
pub const __USE_POSIX = @as(c_int, 1);
pub const __USE_POSIX2 = @as(c_int, 1);
pub const __USE_POSIX199309 = @as(c_int, 1);
pub const __USE_POSIX199506 = @as(c_int, 1);
pub const __USE_XOPEN2K = @as(c_int, 1);
pub const __USE_XOPEN2K8 = @as(c_int, 1);
pub const _ATFILE_SOURCE = @as(c_int, 1);
pub const __USE_XOPEN = @as(c_int, 1);
pub const __USE_XOPEN_EXTENDED = @as(c_int, 1);
pub const __USE_UNIX98 = @as(c_int, 1);
pub const _LARGEFILE_SOURCE = @as(c_int, 1);
pub const __USE_XOPEN2K8XSI = @as(c_int, 1);
pub const __USE_XOPEN2KXSI = @as(c_int, 1);
pub const __USE_ISOC95 = @as(c_int, 1);
pub const __USE_ISOC99 = @as(c_int, 1);
pub const __USE_LARGEFILE = @as(c_int, 1);
pub const __USE_LARGEFILE64 = @as(c_int, 1);
pub const __USE_FILE_OFFSET64 = @as(c_int, 1);
pub const __WORDSIZE = @as(c_int, 64);
pub const __WORDSIZE_TIME64_COMPAT32 = @as(c_int, 1);
pub const __SYSCALL_WORDSIZE = @as(c_int, 64);
pub const __TIMESIZE = __WORDSIZE;
pub const __USE_MISC = @as(c_int, 1);
pub const __USE_ATFILE = @as(c_int, 1);
pub const __USE_DYNAMIC_STACK_SIZE = @as(c_int, 1);
pub const __USE_GNU = @as(c_int, 1);
pub const __USE_FORTIFY_LEVEL = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_GETS = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_SCANF = @as(c_int, 0);
pub const __GLIBC_USE_C2X_STRTOL = @as(c_int, 1);
pub const _STDC_PREDEF_H = @as(c_int, 1);
pub const __STDC_IEC_559__ = @as(c_int, 1);
pub const __STDC_IEC_60559_BFP__ = @as(c_long, 201404);
pub const __STDC_IEC_559_COMPLEX__ = @as(c_int, 1);
pub const __STDC_IEC_60559_COMPLEX__ = @as(c_long, 201404);
pub const __STDC_ISO_10646__ = @as(c_long, 201706);
pub const __GNU_LIBRARY__ = @as(c_int, 6);
pub const __GLIBC__ = @as(c_int, 2);
pub inline fn __GLIBC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub const _SYS_CDEFS_H = @as(c_int, 1);
pub const __glibc_has_attribute = @compileError("unable to translate macro: undefined identifier `__has_attribute`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:45:10
pub inline fn __glibc_has_builtin(name: anytype) @TypeOf(__builtin.has_builtin(name)) {
    _ = &name;
    return __builtin.has_builtin(name);
}
pub const __glibc_has_extension = @compileError("unable to translate macro: undefined identifier `__has_extension`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:55:10
pub const __LEAF = @compileError("unable to translate macro: undefined identifier `__leaf__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:65:11
pub const __LEAF_ATTR = @compileError("unable to translate macro: undefined identifier `__leaf__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:66:11
pub const __THROW = @compileError("unable to translate macro: undefined identifier `__nothrow__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:79:11
pub const __THROWNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:80:11
pub const __NTH = @compileError("unable to translate macro: undefined identifier `__nothrow__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:81:11
pub const __NTHNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:82:11
pub const __COLD = @compileError("unable to translate macro: undefined identifier `__cold__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:102:11
pub inline fn __P(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub inline fn __PMT(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub const __CONCAT = @compileError("unable to translate C expr: unexpected token '##'"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:131:9
pub const __STRING = @compileError("unable to translate C expr: unexpected token ''"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:132:9
pub const __ptr_t = ?*anyopaque;
pub const __BEGIN_DECLS = "";
pub const __END_DECLS = "";
pub inline fn __bos(ptr: anytype) @TypeOf(__builtin.object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1))) {
    _ = &ptr;
    return __builtin.object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1));
}
pub inline fn __bos0(ptr: anytype) @TypeOf(__builtin.object_size(ptr, @as(c_int, 0))) {
    _ = &ptr;
    return __builtin.object_size(ptr, @as(c_int, 0));
}
pub inline fn __glibc_objsize0(__o: anytype) @TypeOf(__bos0(__o)) {
    _ = &__o;
    return __bos0(__o);
}
pub inline fn __glibc_objsize(__o: anytype) @TypeOf(__bos(__o)) {
    _ = &__o;
    return __bos(__o);
}
pub const __warnattr = @compileError("unable to translate macro: undefined identifier `__warning__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:212:10
pub const __errordecl = @compileError("unable to translate macro: undefined identifier `__error__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:213:10
pub const __flexarr = @compileError("unable to translate C expr: unexpected token '['"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:225:10
pub const __glibc_c99_flexarr_available = @as(c_int, 1);
pub const __REDIRECT = @compileError("unable to translate C expr: unexpected token '__asm__'"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:256:10
pub const __REDIRECT_NTH = @compileError("unable to translate C expr: unexpected token '__asm__'"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:263:11
pub const __REDIRECT_NTHNL = @compileError("unable to translate C expr: unexpected token '__asm__'"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:265:11
pub const __ASMNAME = @compileError("unable to translate macro: undefined identifier `__USER_LABEL_PREFIX__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:268:10
pub inline fn __ASMNAME2(prefix: anytype, cname: anytype) @TypeOf(__STRING(prefix) ++ cname) {
    _ = &prefix;
    _ = &cname;
    return __STRING(prefix) ++ cname;
}
pub const __REDIRECT_FORTIFY = __REDIRECT;
pub const __REDIRECT_FORTIFY_NTH = __REDIRECT_NTH;
pub const __attribute_malloc__ = @compileError("unable to translate macro: undefined identifier `__malloc__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:298:10
pub const __attribute_alloc_size__ = @compileError("unable to translate macro: undefined identifier `__alloc_size__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:306:10
pub const __attribute_alloc_align__ = @compileError("unable to translate macro: undefined identifier `__alloc_align__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:315:10
pub const __attribute_pure__ = @compileError("unable to translate macro: undefined identifier `__pure__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:325:10
pub const __attribute_const__ = @compileError("unable to translate C expr: unexpected token '__attribute__'"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:332:10
pub const __attribute_maybe_unused__ = @compileError("unable to translate macro: undefined identifier `__unused__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:338:10
pub const __attribute_used__ = @compileError("unable to translate macro: undefined identifier `__used__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:347:10
pub const __attribute_noinline__ = @compileError("unable to translate macro: undefined identifier `__noinline__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:348:10
pub const __attribute_deprecated__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:356:10
pub const __attribute_deprecated_msg__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:366:10
pub const __attribute_format_arg__ = @compileError("unable to translate macro: undefined identifier `__format_arg__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:379:10
pub const __attribute_format_strfmon__ = @compileError("unable to translate macro: undefined identifier `__format__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:389:10
pub const __attribute_nonnull__ = @compileError("unable to translate macro: undefined identifier `__nonnull__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:401:11
pub inline fn __nonnull(params: anytype) @TypeOf(__attribute_nonnull__(params)) {
    _ = &params;
    return __attribute_nonnull__(params);
}
pub const __returns_nonnull = @compileError("unable to translate macro: undefined identifier `__returns_nonnull__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:414:10
pub const __attribute_warn_unused_result__ = @compileError("unable to translate macro: undefined identifier `__warn_unused_result__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:423:10
pub const __wur = "";
pub const __always_inline = @compileError("unable to translate macro: undefined identifier `__always_inline__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:441:10
pub const __attribute_artificial__ = @compileError("unable to translate macro: undefined identifier `__artificial__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:450:10
pub const __extern_inline = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:472:11
pub const __extern_always_inline = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:473:11
pub const __fortify_function = __extern_always_inline ++ __attribute_artificial__;
pub const __va_arg_pack = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg_pack`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:484:10
pub const __va_arg_pack_len = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg_pack_len`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:485:10
pub const __restrict_arr = @compileError("unable to translate C expr: unexpected token '__restrict'"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:512:10
pub inline fn __glibc_unlikely(cond: anytype) @TypeOf(__builtin.expect(cond, @as(c_int, 0))) {
    _ = &cond;
    return __builtin.expect(cond, @as(c_int, 0));
}
pub inline fn __glibc_likely(cond: anytype) @TypeOf(__builtin.expect(cond, @as(c_int, 1))) {
    _ = &cond;
    return __builtin.expect(cond, @as(c_int, 1));
}
pub const __attribute_nonstring__ = "";
pub inline fn __attribute_copy__(arg: anytype) void {
    _ = &arg;
    return;
}
pub const __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI = @as(c_int, 0);
pub inline fn __LDBL_REDIR1(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR(name: anytype, proto: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR1_NTH(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR_NTH(name: anytype, proto: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR2_DECL(name: anytype) void {
    _ = &name;
    return;
}
pub inline fn __LDBL_REDIR_DECL(name: anytype) void {
    _ = &name;
    return;
}
pub inline fn __REDIRECT_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT(name, proto, alias);
}
pub inline fn __REDIRECT_NTH_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT_NTH(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT_NTH(name, proto, alias);
}
pub const __glibc_macro_warning1 = @compileError("unable to translate macro: undefined identifier `_Pragma`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:653:10
pub const __glibc_macro_warning = @compileError("unable to translate macro: undefined identifier `GCC`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:654:10
pub const __HAVE_GENERIC_SELECTION = @as(c_int, 1);
pub inline fn __fortified_attr_access(a: anytype, o: anytype, s: anytype) void {
    _ = &a;
    _ = &o;
    _ = &s;
    return;
}
pub inline fn __attr_access(x: anytype) void {
    _ = &x;
    return;
}
pub inline fn __attr_access_none(argno: anytype) void {
    _ = &argno;
    return;
}
pub inline fn __attr_dealloc(dealloc: anytype, argno: anytype) void {
    _ = &dealloc;
    _ = &argno;
    return;
}
pub const __attr_dealloc_free = "";
pub const __attribute_returns_twice__ = @compileError("unable to translate macro: undefined identifier `__returns_twice__`"); // /usr/include/x86_64-linux-gnu/sys/cdefs.h:718:10
pub const __USE_EXTERN_INLINES = @as(c_int, 1);
pub const __stub___compat_bdflush = "";
pub const __stub_chflags = "";
pub const __stub_fchflags = "";
pub const __stub_gtty = "";
pub const __stub_revoke = "";
pub const __stub_setlogin = "";
pub const __stub_sigreturn = "";
pub const __stub_stty = "";
pub const __ASSERT_VOID_CAST = @compileError("unable to translate C expr: unexpected token ''"); // /usr/include/assert.h:40:10
pub inline fn assert(expr: anytype) @TypeOf(__ASSERT_VOID_CAST(@as(c_int, 0))) {
    _ = &expr;
    return __ASSERT_VOID_CAST(@as(c_int, 0));
}
pub inline fn assert_perror(errnum: anytype) @TypeOf(__ASSERT_VOID_CAST(@as(c_int, 0))) {
    _ = &errnum;
    return __ASSERT_VOID_CAST(@as(c_int, 0));
}
pub const static_assert = @compileError("unable to translate C expr: unexpected token '_Static_assert'"); // /usr/include/assert.h:158:10
pub const __CLANG_INTTYPES_H = "";
pub const _INTTYPES_H = @as(c_int, 1);
pub const __CLANG_STDINT_H = "";
pub const _STDINT_H = @as(c_int, 1);
pub const _BITS_TYPES_H = @as(c_int, 1);
pub const __S16_TYPE = c_short;
pub const __U16_TYPE = c_ushort;
pub const __S32_TYPE = c_int;
pub const __U32_TYPE = c_uint;
pub const __SLONGWORD_TYPE = c_long;
pub const __ULONGWORD_TYPE = c_ulong;
pub const __SQUAD_TYPE = c_long;
pub const __UQUAD_TYPE = c_ulong;
pub const __SWORD_TYPE = c_long;
pub const __UWORD_TYPE = c_ulong;
pub const __SLONG32_TYPE = c_int;
pub const __ULONG32_TYPE = c_uint;
pub const __S64_TYPE = c_long;
pub const __U64_TYPE = c_ulong;
pub const _BITS_TYPESIZES_H = @as(c_int, 1);
pub const __SYSCALL_SLONG_TYPE = __SLONGWORD_TYPE;
pub const __SYSCALL_ULONG_TYPE = __ULONGWORD_TYPE;
pub const __DEV_T_TYPE = __UQUAD_TYPE;
pub const __UID_T_TYPE = __U32_TYPE;
pub const __GID_T_TYPE = __U32_TYPE;
pub const __INO_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __INO64_T_TYPE = __UQUAD_TYPE;
pub const __MODE_T_TYPE = __U32_TYPE;
pub const __NLINK_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSWORD_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF64_T_TYPE = __SQUAD_TYPE;
pub const __PID_T_TYPE = __S32_TYPE;
pub const __RLIM_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __RLIM64_T_TYPE = __UQUAD_TYPE;
pub const __BLKCNT_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __BLKCNT64_T_TYPE = __SQUAD_TYPE;
pub const __FSBLKCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSBLKCNT64_T_TYPE = __UQUAD_TYPE;
pub const __FSFILCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSFILCNT64_T_TYPE = __UQUAD_TYPE;
pub const __ID_T_TYPE = __U32_TYPE;
pub const __CLOCK_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __TIME_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __USECONDS_T_TYPE = __U32_TYPE;
pub const __SUSECONDS_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __SUSECONDS64_T_TYPE = __SQUAD_TYPE;
pub const __DADDR_T_TYPE = __S32_TYPE;
pub const __KEY_T_TYPE = __S32_TYPE;
pub const __CLOCKID_T_TYPE = __S32_TYPE;
pub const __TIMER_T_TYPE = ?*anyopaque;
pub const __BLKSIZE_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __FSID_T_TYPE = @compileError("unable to translate macro: undefined identifier `__val`"); // /usr/include/x86_64-linux-gnu/bits/typesizes.h:73:9
pub const __SSIZE_T_TYPE = __SWORD_TYPE;
pub const __CPU_MASK_TYPE = __SYSCALL_ULONG_TYPE;
pub const __OFF_T_MATCHES_OFF64_T = @as(c_int, 1);
pub const __INO_T_MATCHES_INO64_T = @as(c_int, 1);
pub const __RLIM_T_MATCHES_RLIM64_T = @as(c_int, 1);
pub const __STATFS_MATCHES_STATFS64 = @as(c_int, 1);
pub const __KERNEL_OLD_TIMEVAL_MATCHES_TIMEVAL64 = @as(c_int, 1);
pub const _BITS_TIME64_H = @as(c_int, 1);
pub const __TIME64_T_TYPE = __TIME_T_TYPE;
pub const _BITS_WCHAR_H = @as(c_int, 1);
pub const __WCHAR_MAX = __WCHAR_MAX__;
pub const __WCHAR_MIN = -__WCHAR_MAX - @as(c_int, 1);
pub const _BITS_STDINT_INTN_H = @as(c_int, 1);
pub const _BITS_STDINT_UINTN_H = @as(c_int, 1);
pub const _BITS_STDINT_LEAST_H = @as(c_int, 1);
pub const __intptr_t_defined = "";
pub const INT8_MIN = -@as(c_int, 128);
pub const INT16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT32_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT8_MAX = @as(c_int, 127);
pub const INT16_MAX = @as(c_int, 32767);
pub const INT32_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT8_MAX = @as(c_int, 255);
pub const UINT16_MAX = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT32_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_LEAST8_MIN = -@as(c_int, 128);
pub const INT_LEAST16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT_LEAST32_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT_LEAST64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_LEAST8_MAX = @as(c_int, 127);
pub const INT_LEAST16_MAX = @as(c_int, 32767);
pub const INT_LEAST32_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT_LEAST64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_LEAST8_MAX = @as(c_int, 255);
pub const UINT_LEAST16_MAX = __helpers.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST32_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_FAST8_MIN = -@as(c_int, 128);
pub const INT_FAST16_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST32_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST64_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_FAST8_MAX = @as(c_int, 127);
pub const INT_FAST16_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST32_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST64_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_FAST8_MAX = @as(c_int, 255);
pub const UINT_FAST16_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST32_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INTPTR_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INTPTR_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const UINTPTR_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const INTMAX_MIN = -__INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INTMAX_MAX = __INT64_C(__helpers.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINTMAX_MAX = __UINT64_C(__helpers.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const PTRDIFF_MIN = -__helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const PTRDIFF_MAX = __helpers.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const SIG_ATOMIC_MIN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const SIG_ATOMIC_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const SIZE_MAX = __helpers.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const WCHAR_MIN = __WCHAR_MIN;
pub const WCHAR_MAX = __WCHAR_MAX;
pub const WINT_MIN = @as(c_uint, 0);
pub const WINT_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub inline fn INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const INT64_C = __helpers.L_SUFFIX;
pub inline fn UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const UINT32_C = __helpers.U_SUFFIX;
pub const UINT64_C = __helpers.UL_SUFFIX;
pub const INTMAX_C = __helpers.L_SUFFIX;
pub const UINTMAX_C = __helpers.UL_SUFFIX;
pub const INT8_WIDTH = @as(c_int, 8);
pub const UINT8_WIDTH = @as(c_int, 8);
pub const INT16_WIDTH = @as(c_int, 16);
pub const UINT16_WIDTH = @as(c_int, 16);
pub const INT32_WIDTH = @as(c_int, 32);
pub const UINT32_WIDTH = @as(c_int, 32);
pub const INT64_WIDTH = @as(c_int, 64);
pub const UINT64_WIDTH = @as(c_int, 64);
pub const INT_LEAST8_WIDTH = @as(c_int, 8);
pub const UINT_LEAST8_WIDTH = @as(c_int, 8);
pub const INT_LEAST16_WIDTH = @as(c_int, 16);
pub const UINT_LEAST16_WIDTH = @as(c_int, 16);
pub const INT_LEAST32_WIDTH = @as(c_int, 32);
pub const UINT_LEAST32_WIDTH = @as(c_int, 32);
pub const INT_LEAST64_WIDTH = @as(c_int, 64);
pub const UINT_LEAST64_WIDTH = @as(c_int, 64);
pub const INT_FAST8_WIDTH = @as(c_int, 8);
pub const UINT_FAST8_WIDTH = @as(c_int, 8);
pub const INT_FAST16_WIDTH = __WORDSIZE;
pub const UINT_FAST16_WIDTH = __WORDSIZE;
pub const INT_FAST32_WIDTH = __WORDSIZE;
pub const UINT_FAST32_WIDTH = __WORDSIZE;
pub const INT_FAST64_WIDTH = @as(c_int, 64);
pub const UINT_FAST64_WIDTH = @as(c_int, 64);
pub const INTPTR_WIDTH = __WORDSIZE;
pub const UINTPTR_WIDTH = __WORDSIZE;
pub const INTMAX_WIDTH = @as(c_int, 64);
pub const UINTMAX_WIDTH = @as(c_int, 64);
pub const PTRDIFF_WIDTH = __WORDSIZE;
pub const SIG_ATOMIC_WIDTH = @as(c_int, 32);
pub const SIZE_WIDTH = __WORDSIZE;
pub const WCHAR_WIDTH = @as(c_int, 32);
pub const WINT_WIDTH = @as(c_int, 32);
pub const ____gwchar_t_defined = @as(c_int, 1);
pub const __PRI64_PREFIX = "l";
pub const __PRIPTR_PREFIX = "l";
pub const PRId8 = "d";
pub const PRId16 = "d";
pub const PRId32 = "d";
pub const PRId64 = __PRI64_PREFIX ++ "d";
pub const PRIdLEAST8 = "d";
pub const PRIdLEAST16 = "d";
pub const PRIdLEAST32 = "d";
pub const PRIdLEAST64 = __PRI64_PREFIX ++ "d";
pub const PRIdFAST8 = "d";
pub const PRIdFAST16 = __PRIPTR_PREFIX ++ "d";
pub const PRIdFAST32 = __PRIPTR_PREFIX ++ "d";
pub const PRIdFAST64 = __PRI64_PREFIX ++ "d";
pub const PRIi8 = "i";
pub const PRIi16 = "i";
pub const PRIi32 = "i";
pub const PRIi64 = __PRI64_PREFIX ++ "i";
pub const PRIiLEAST8 = "i";
pub const PRIiLEAST16 = "i";
pub const PRIiLEAST32 = "i";
pub const PRIiLEAST64 = __PRI64_PREFIX ++ "i";
pub const PRIiFAST8 = "i";
pub const PRIiFAST16 = __PRIPTR_PREFIX ++ "i";
pub const PRIiFAST32 = __PRIPTR_PREFIX ++ "i";
pub const PRIiFAST64 = __PRI64_PREFIX ++ "i";
pub const PRIo8 = "o";
pub const PRIo16 = "o";
pub const PRIo32 = "o";
pub const PRIo64 = __PRI64_PREFIX ++ "o";
pub const PRIoLEAST8 = "o";
pub const PRIoLEAST16 = "o";
pub const PRIoLEAST32 = "o";
pub const PRIoLEAST64 = __PRI64_PREFIX ++ "o";
pub const PRIoFAST8 = "o";
pub const PRIoFAST16 = __PRIPTR_PREFIX ++ "o";
pub const PRIoFAST32 = __PRIPTR_PREFIX ++ "o";
pub const PRIoFAST64 = __PRI64_PREFIX ++ "o";
pub const PRIu8 = "u";
pub const PRIu16 = "u";
pub const PRIu32 = "u";
pub const PRIu64 = __PRI64_PREFIX ++ "u";
pub const PRIuLEAST8 = "u";
pub const PRIuLEAST16 = "u";
pub const PRIuLEAST32 = "u";
pub const PRIuLEAST64 = __PRI64_PREFIX ++ "u";
pub const PRIuFAST8 = "u";
pub const PRIuFAST16 = __PRIPTR_PREFIX ++ "u";
pub const PRIuFAST32 = __PRIPTR_PREFIX ++ "u";
pub const PRIuFAST64 = __PRI64_PREFIX ++ "u";
pub const PRIx8 = "x";
pub const PRIx16 = "x";
pub const PRIx32 = "x";
pub const PRIx64 = __PRI64_PREFIX ++ "x";
pub const PRIxLEAST8 = "x";
pub const PRIxLEAST16 = "x";
pub const PRIxLEAST32 = "x";
pub const PRIxLEAST64 = __PRI64_PREFIX ++ "x";
pub const PRIxFAST8 = "x";
pub const PRIxFAST16 = __PRIPTR_PREFIX ++ "x";
pub const PRIxFAST32 = __PRIPTR_PREFIX ++ "x";
pub const PRIxFAST64 = __PRI64_PREFIX ++ "x";
pub const PRIX8 = "X";
pub const PRIX16 = "X";
pub const PRIX32 = "X";
pub const PRIX64 = __PRI64_PREFIX ++ "X";
pub const PRIXLEAST8 = "X";
pub const PRIXLEAST16 = "X";
pub const PRIXLEAST32 = "X";
pub const PRIXLEAST64 = __PRI64_PREFIX ++ "X";
pub const PRIXFAST8 = "X";
pub const PRIXFAST16 = __PRIPTR_PREFIX ++ "X";
pub const PRIXFAST32 = __PRIPTR_PREFIX ++ "X";
pub const PRIXFAST64 = __PRI64_PREFIX ++ "X";
pub const PRIdMAX = __PRI64_PREFIX ++ "d";
pub const PRIiMAX = __PRI64_PREFIX ++ "i";
pub const PRIoMAX = __PRI64_PREFIX ++ "o";
pub const PRIuMAX = __PRI64_PREFIX ++ "u";
pub const PRIxMAX = __PRI64_PREFIX ++ "x";
pub const PRIXMAX = __PRI64_PREFIX ++ "X";
pub const PRIdPTR = __PRIPTR_PREFIX ++ "d";
pub const PRIiPTR = __PRIPTR_PREFIX ++ "i";
pub const PRIoPTR = __PRIPTR_PREFIX ++ "o";
pub const PRIuPTR = __PRIPTR_PREFIX ++ "u";
pub const PRIxPTR = __PRIPTR_PREFIX ++ "x";
pub const PRIXPTR = __PRIPTR_PREFIX ++ "X";
pub const PRIb8 = "b";
pub const PRIb16 = "b";
pub const PRIb32 = "b";
pub const PRIb64 = __PRI64_PREFIX ++ "b";
pub const PRIbLEAST8 = "b";
pub const PRIbLEAST16 = "b";
pub const PRIbLEAST32 = "b";
pub const PRIbLEAST64 = __PRI64_PREFIX ++ "b";
pub const PRIbFAST8 = "b";
pub const PRIbFAST16 = __PRIPTR_PREFIX ++ "b";
pub const PRIbFAST32 = __PRIPTR_PREFIX ++ "b";
pub const PRIbFAST64 = __PRI64_PREFIX ++ "b";
pub const PRIbMAX = __PRI64_PREFIX ++ "b";
pub const PRIbPTR = __PRIPTR_PREFIX ++ "b";
pub const PRIB8 = "B";
pub const PRIB16 = "B";
pub const PRIB32 = "B";
pub const PRIB64 = __PRI64_PREFIX ++ "B";
pub const PRIBLEAST8 = "B";
pub const PRIBLEAST16 = "B";
pub const PRIBLEAST32 = "B";
pub const PRIBLEAST64 = __PRI64_PREFIX ++ "B";
pub const PRIBFAST8 = "B";
pub const PRIBFAST16 = __PRIPTR_PREFIX ++ "B";
pub const PRIBFAST32 = __PRIPTR_PREFIX ++ "B";
pub const PRIBFAST64 = __PRI64_PREFIX ++ "B";
pub const PRIBMAX = __PRI64_PREFIX ++ "B";
pub const PRIBPTR = __PRIPTR_PREFIX ++ "B";
pub const SCNd8 = "hhd";
pub const SCNd16 = "hd";
pub const SCNd32 = "d";
pub const SCNd64 = __PRI64_PREFIX ++ "d";
pub const SCNdLEAST8 = "hhd";
pub const SCNdLEAST16 = "hd";
pub const SCNdLEAST32 = "d";
pub const SCNdLEAST64 = __PRI64_PREFIX ++ "d";
pub const SCNdFAST8 = "hhd";
pub const SCNdFAST16 = __PRIPTR_PREFIX ++ "d";
pub const SCNdFAST32 = __PRIPTR_PREFIX ++ "d";
pub const SCNdFAST64 = __PRI64_PREFIX ++ "d";
pub const SCNi8 = "hhi";
pub const SCNi16 = "hi";
pub const SCNi32 = "i";
pub const SCNi64 = __PRI64_PREFIX ++ "i";
pub const SCNiLEAST8 = "hhi";
pub const SCNiLEAST16 = "hi";
pub const SCNiLEAST32 = "i";
pub const SCNiLEAST64 = __PRI64_PREFIX ++ "i";
pub const SCNiFAST8 = "hhi";
pub const SCNiFAST16 = __PRIPTR_PREFIX ++ "i";
pub const SCNiFAST32 = __PRIPTR_PREFIX ++ "i";
pub const SCNiFAST64 = __PRI64_PREFIX ++ "i";
pub const SCNu8 = "hhu";
pub const SCNu16 = "hu";
pub const SCNu32 = "u";
pub const SCNu64 = __PRI64_PREFIX ++ "u";
pub const SCNuLEAST8 = "hhu";
pub const SCNuLEAST16 = "hu";
pub const SCNuLEAST32 = "u";
pub const SCNuLEAST64 = __PRI64_PREFIX ++ "u";
pub const SCNuFAST8 = "hhu";
pub const SCNuFAST16 = __PRIPTR_PREFIX ++ "u";
pub const SCNuFAST32 = __PRIPTR_PREFIX ++ "u";
pub const SCNuFAST64 = __PRI64_PREFIX ++ "u";
pub const SCNo8 = "hho";
pub const SCNo16 = "ho";
pub const SCNo32 = "o";
pub const SCNo64 = __PRI64_PREFIX ++ "o";
pub const SCNoLEAST8 = "hho";
pub const SCNoLEAST16 = "ho";
pub const SCNoLEAST32 = "o";
pub const SCNoLEAST64 = __PRI64_PREFIX ++ "o";
pub const SCNoFAST8 = "hho";
pub const SCNoFAST16 = __PRIPTR_PREFIX ++ "o";
pub const SCNoFAST32 = __PRIPTR_PREFIX ++ "o";
pub const SCNoFAST64 = __PRI64_PREFIX ++ "o";
pub const SCNx8 = "hhx";
pub const SCNx16 = "hx";
pub const SCNx32 = "x";
pub const SCNx64 = __PRI64_PREFIX ++ "x";
pub const SCNxLEAST8 = "hhx";
pub const SCNxLEAST16 = "hx";
pub const SCNxLEAST32 = "x";
pub const SCNxLEAST64 = __PRI64_PREFIX ++ "x";
pub const SCNxFAST8 = "hhx";
pub const SCNxFAST16 = __PRIPTR_PREFIX ++ "x";
pub const SCNxFAST32 = __PRIPTR_PREFIX ++ "x";
pub const SCNxFAST64 = __PRI64_PREFIX ++ "x";
pub const SCNdMAX = __PRI64_PREFIX ++ "d";
pub const SCNiMAX = __PRI64_PREFIX ++ "i";
pub const SCNoMAX = __PRI64_PREFIX ++ "o";
pub const SCNuMAX = __PRI64_PREFIX ++ "u";
pub const SCNxMAX = __PRI64_PREFIX ++ "x";
pub const SCNdPTR = __PRIPTR_PREFIX ++ "d";
pub const SCNiPTR = __PRIPTR_PREFIX ++ "i";
pub const SCNoPTR = __PRIPTR_PREFIX ++ "o";
pub const SCNuPTR = __PRIPTR_PREFIX ++ "u";
pub const SCNxPTR = __PRIPTR_PREFIX ++ "x";
pub const SCNb8 = "hhb";
pub const SCNb16 = "hb";
pub const SCNb32 = "b";
pub const SCNb64 = __PRI64_PREFIX ++ "b";
pub const SCNbLEAST8 = "hhb";
pub const SCNbLEAST16 = "hb";
pub const SCNbLEAST32 = "b";
pub const SCNbLEAST64 = __PRI64_PREFIX ++ "b";
pub const SCNbFAST8 = "hhb";
pub const SCNbFAST16 = __PRIPTR_PREFIX ++ "b";
pub const SCNbFAST32 = __PRIPTR_PREFIX ++ "b";
pub const SCNbFAST64 = __PRI64_PREFIX ++ "b";
pub const SCNbMAX = __PRI64_PREFIX ++ "b";
pub const SCNbPTR = __PRIPTR_PREFIX ++ "b";
pub const _GCC_LIMITS_H_ = "";
pub const __CLANG_LIMITS_H = "";
pub const _LIBC_LIMITS_H_ = @as(c_int, 1);
pub const MB_LEN_MAX = @as(c_int, 16);
pub const CHAR_WIDTH = @as(c_int, 8);
pub const SCHAR_WIDTH = @as(c_int, 8);
pub const UCHAR_WIDTH = @as(c_int, 8);
pub const SHRT_WIDTH = @as(c_int, 16);
pub const USHRT_WIDTH = @as(c_int, 16);
pub const INT_WIDTH = @as(c_int, 32);
pub const UINT_WIDTH = @as(c_int, 32);
pub const LONG_WIDTH = __WORDSIZE;
pub const ULONG_WIDTH = __WORDSIZE;
pub const LLONG_WIDTH = @as(c_int, 64);
pub const ULLONG_WIDTH = @as(c_int, 64);
pub const BOOL_MAX = @as(c_int, 1);
pub const BOOL_WIDTH = @as(c_int, 1);
pub const _BITS_POSIX1_LIM_H = @as(c_int, 1);
pub const _POSIX_AIO_LISTIO_MAX = @as(c_int, 2);
pub const _POSIX_AIO_MAX = @as(c_int, 1);
pub const _POSIX_ARG_MAX = @as(c_int, 4096);
pub const _POSIX_CHILD_MAX = @as(c_int, 25);
pub const _POSIX_DELAYTIMER_MAX = @as(c_int, 32);
pub const _POSIX_HOST_NAME_MAX = @as(c_int, 255);
pub const _POSIX_LINK_MAX = @as(c_int, 8);
pub const _POSIX_LOGIN_NAME_MAX = @as(c_int, 9);
pub const _POSIX_MAX_CANON = @as(c_int, 255);
pub const _POSIX_MAX_INPUT = @as(c_int, 255);
pub const _POSIX_MQ_OPEN_MAX = @as(c_int, 8);
pub const _POSIX_MQ_PRIO_MAX = @as(c_int, 32);
pub const _POSIX_NAME_MAX = @as(c_int, 14);
pub const _POSIX_NGROUPS_MAX = @as(c_int, 8);
pub const _POSIX_OPEN_MAX = @as(c_int, 20);
pub const _POSIX_FD_SETSIZE = _POSIX_OPEN_MAX;
pub const _POSIX_PATH_MAX = @as(c_int, 256);
pub const _POSIX_PIPE_BUF = @as(c_int, 512);
pub const _POSIX_RE_DUP_MAX = @as(c_int, 255);
pub const _POSIX_RTSIG_MAX = @as(c_int, 8);
pub const _POSIX_SEM_NSEMS_MAX = @as(c_int, 256);
pub const _POSIX_SEM_VALUE_MAX = @as(c_int, 32767);
pub const _POSIX_SIGQUEUE_MAX = @as(c_int, 32);
pub const _POSIX_SSIZE_MAX = @as(c_int, 32767);
pub const _POSIX_STREAM_MAX = @as(c_int, 8);
pub const _POSIX_SYMLINK_MAX = @as(c_int, 255);
pub const _POSIX_SYMLOOP_MAX = @as(c_int, 8);
pub const _POSIX_TIMER_MAX = @as(c_int, 32);
pub const _POSIX_TTY_NAME_MAX = @as(c_int, 9);
pub const _POSIX_TZNAME_MAX = @as(c_int, 6);
pub const _POSIX_QLIMIT = @as(c_int, 1);
pub const _POSIX_HIWAT = _POSIX_PIPE_BUF;
pub const _POSIX_UIO_MAXIOV = @as(c_int, 16);
pub const _POSIX_CLOCKRES_MIN = __helpers.promoteIntLiteral(c_int, 20000000, .decimal);
pub const _LINUX_LIMITS_H = "";
pub const NGROUPS_MAX = __helpers.promoteIntLiteral(c_int, 65536, .decimal);
pub const MAX_CANON = @as(c_int, 255);
pub const MAX_INPUT = @as(c_int, 255);
pub const NAME_MAX = @as(c_int, 255);
pub const PATH_MAX = @as(c_int, 4096);
pub const PIPE_BUF = @as(c_int, 4096);
pub const XATTR_NAME_MAX = @as(c_int, 255);
pub const XATTR_SIZE_MAX = __helpers.promoteIntLiteral(c_int, 65536, .decimal);
pub const XATTR_LIST_MAX = __helpers.promoteIntLiteral(c_int, 65536, .decimal);
pub const RTSIG_MAX = @as(c_int, 32);
pub const _POSIX_THREAD_KEYS_MAX = @as(c_int, 128);
pub const PTHREAD_KEYS_MAX = @as(c_int, 1024);
pub const _POSIX_THREAD_DESTRUCTOR_ITERATIONS = @as(c_int, 4);
pub const PTHREAD_DESTRUCTOR_ITERATIONS = _POSIX_THREAD_DESTRUCTOR_ITERATIONS;
pub const _POSIX_THREAD_THREADS_MAX = @as(c_int, 64);
pub const AIO_PRIO_DELTA_MAX = @as(c_int, 20);
pub const __SC_THREAD_STACK_MIN_VALUE = @as(c_int, 75);
pub const PTHREAD_STACK_MIN = __sysconf(__SC_THREAD_STACK_MIN_VALUE);
pub const DELAYTIMER_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const TTY_NAME_MAX = @as(c_int, 32);
pub const LOGIN_NAME_MAX = @as(c_int, 256);
pub const HOST_NAME_MAX = @as(c_int, 64);
pub const MQ_PRIO_MAX = __helpers.promoteIntLiteral(c_int, 32768, .decimal);
pub const SEM_VALUE_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const SSIZE_MAX = LONG_MAX;
pub const _BITS_POSIX2_LIM_H = @as(c_int, 1);
pub const _POSIX2_BC_BASE_MAX = @as(c_int, 99);
pub const _POSIX2_BC_DIM_MAX = @as(c_int, 2048);
pub const _POSIX2_BC_SCALE_MAX = @as(c_int, 99);
pub const _POSIX2_BC_STRING_MAX = @as(c_int, 1000);
pub const _POSIX2_COLL_WEIGHTS_MAX = @as(c_int, 2);
pub const _POSIX2_EXPR_NEST_MAX = @as(c_int, 32);
pub const _POSIX2_LINE_MAX = @as(c_int, 2048);
pub const _POSIX2_RE_DUP_MAX = @as(c_int, 255);
pub const _POSIX2_CHARCLASS_NAME_MAX = @as(c_int, 14);
pub const BC_BASE_MAX = _POSIX2_BC_BASE_MAX;
pub const BC_DIM_MAX = _POSIX2_BC_DIM_MAX;
pub const BC_SCALE_MAX = _POSIX2_BC_SCALE_MAX;
pub const BC_STRING_MAX = _POSIX2_BC_STRING_MAX;
pub const COLL_WEIGHTS_MAX = @as(c_int, 255);
pub const EXPR_NEST_MAX = _POSIX2_EXPR_NEST_MAX;
pub const LINE_MAX = _POSIX2_LINE_MAX;
pub const CHARCLASS_NAME_MAX = @as(c_int, 2048);
pub const RE_DUP_MAX = @as(c_int, 0x7fff);
pub const _XOPEN_LIM_H = @as(c_int, 1);
pub const _XOPEN_IOV_MAX = _POSIX_UIO_MAXIOV;
pub const _BITS_UIO_LIM_H = @as(c_int, 1);
pub const __IOV_MAX = @as(c_int, 1024);
pub const IOV_MAX = __IOV_MAX;
pub const NL_ARGMAX = _POSIX_ARG_MAX;
pub const NL_LANGMAX = _POSIX2_LINE_MAX;
pub const NL_MSGMAX = INT_MAX;
pub const NL_NMAX = INT_MAX;
pub const NL_SETMAX = INT_MAX;
pub const NL_TEXTMAX = INT_MAX;
pub const NZERO = @as(c_int, 20);
pub const WORD_BIT = @as(c_int, 32);
pub const LONG_BIT = @as(c_int, 64);
pub const LONG_LONG_MAX = __LONG_LONG_MAX__;
pub const LONG_LONG_MIN = -__LONG_LONG_MAX__ - @as(c_longlong, 1);
pub const ULONG_LONG_MAX = (__LONG_LONG_MAX__ * @as(c_ulonglong, 2)) + @as(c_ulonglong, 1);
pub const SCHAR_MAX = __SCHAR_MAX__;
pub const SHRT_MAX = __SHRT_MAX__;
pub const INT_MAX = __INT_MAX__;
pub const LONG_MAX = __LONG_MAX__;
pub const SCHAR_MIN = -__SCHAR_MAX__ - @as(c_int, 1);
pub const SHRT_MIN = -__SHRT_MAX__ - @as(c_int, 1);
pub const INT_MIN = -__INT_MAX__ - @as(c_int, 1);
pub const LONG_MIN = -__LONG_MAX__ - @as(c_long, 1);
pub const UCHAR_MAX = (__SCHAR_MAX__ * @as(c_int, 2)) + @as(c_int, 1);
pub const USHRT_MAX = (__SHRT_MAX__ * @as(c_int, 2)) + @as(c_int, 1);
pub const UINT_MAX = (__INT_MAX__ * @as(c_uint, 2)) + @as(c_uint, 1);
pub const ULONG_MAX = (__LONG_MAX__ * @as(c_ulong, 2)) + @as(c_ulong, 1);
pub const CHAR_BIT = __CHAR_BIT__;
pub const CHAR_MIN = SCHAR_MIN;
pub const CHAR_MAX = __SCHAR_MAX__;
pub const LLONG_MIN = -__LONG_LONG_MAX__ - @as(c_longlong, 1);
pub const LLONG_MAX = __LONG_LONG_MAX__;
pub const ULLONG_MAX = (__LONG_LONG_MAX__ * @as(c_ulonglong, 2)) + @as(c_ulonglong, 1);
pub const _MATH_H = @as(c_int, 1);
pub const _BITS_LIBM_SIMD_DECL_STUBS_H = @as(c_int, 1);
pub const __DECL_SIMD_cos = "";
pub const __DECL_SIMD_cosf = "";
pub const __DECL_SIMD_cosl = "";
pub const __DECL_SIMD_cosf16 = "";
pub const __DECL_SIMD_cosf32 = "";
pub const __DECL_SIMD_cosf64 = "";
pub const __DECL_SIMD_cosf128 = "";
pub const __DECL_SIMD_cosf32x = "";
pub const __DECL_SIMD_cosf64x = "";
pub const __DECL_SIMD_cosf128x = "";
pub const __DECL_SIMD_sin = "";
pub const __DECL_SIMD_sinf = "";
pub const __DECL_SIMD_sinl = "";
pub const __DECL_SIMD_sinf16 = "";
pub const __DECL_SIMD_sinf32 = "";
pub const __DECL_SIMD_sinf64 = "";
pub const __DECL_SIMD_sinf128 = "";
pub const __DECL_SIMD_sinf32x = "";
pub const __DECL_SIMD_sinf64x = "";
pub const __DECL_SIMD_sinf128x = "";
pub const __DECL_SIMD_sincos = "";
pub const __DECL_SIMD_sincosf = "";
pub const __DECL_SIMD_sincosl = "";
pub const __DECL_SIMD_sincosf16 = "";
pub const __DECL_SIMD_sincosf32 = "";
pub const __DECL_SIMD_sincosf64 = "";
pub const __DECL_SIMD_sincosf128 = "";
pub const __DECL_SIMD_sincosf32x = "";
pub const __DECL_SIMD_sincosf64x = "";
pub const __DECL_SIMD_sincosf128x = "";
pub const __DECL_SIMD_log = "";
pub const __DECL_SIMD_logf = "";
pub const __DECL_SIMD_logl = "";
pub const __DECL_SIMD_logf16 = "";
pub const __DECL_SIMD_logf32 = "";
pub const __DECL_SIMD_logf64 = "";
pub const __DECL_SIMD_logf128 = "";
pub const __DECL_SIMD_logf32x = "";
pub const __DECL_SIMD_logf64x = "";
pub const __DECL_SIMD_logf128x = "";
pub const __DECL_SIMD_exp = "";
pub const __DECL_SIMD_expf = "";
pub const __DECL_SIMD_expl = "";
pub const __DECL_SIMD_expf16 = "";
pub const __DECL_SIMD_expf32 = "";
pub const __DECL_SIMD_expf64 = "";
pub const __DECL_SIMD_expf128 = "";
pub const __DECL_SIMD_expf32x = "";
pub const __DECL_SIMD_expf64x = "";
pub const __DECL_SIMD_expf128x = "";
pub const __DECL_SIMD_pow = "";
pub const __DECL_SIMD_powf = "";
pub const __DECL_SIMD_powl = "";
pub const __DECL_SIMD_powf16 = "";
pub const __DECL_SIMD_powf32 = "";
pub const __DECL_SIMD_powf64 = "";
pub const __DECL_SIMD_powf128 = "";
pub const __DECL_SIMD_powf32x = "";
pub const __DECL_SIMD_powf64x = "";
pub const __DECL_SIMD_powf128x = "";
pub const __DECL_SIMD_acos = "";
pub const __DECL_SIMD_acosf = "";
pub const __DECL_SIMD_acosl = "";
pub const __DECL_SIMD_acosf16 = "";
pub const __DECL_SIMD_acosf32 = "";
pub const __DECL_SIMD_acosf64 = "";
pub const __DECL_SIMD_acosf128 = "";
pub const __DECL_SIMD_acosf32x = "";
pub const __DECL_SIMD_acosf64x = "";
pub const __DECL_SIMD_acosf128x = "";
pub const __DECL_SIMD_atan = "";
pub const __DECL_SIMD_atanf = "";
pub const __DECL_SIMD_atanl = "";
pub const __DECL_SIMD_atanf16 = "";
pub const __DECL_SIMD_atanf32 = "";
pub const __DECL_SIMD_atanf64 = "";
pub const __DECL_SIMD_atanf128 = "";
pub const __DECL_SIMD_atanf32x = "";
pub const __DECL_SIMD_atanf64x = "";
pub const __DECL_SIMD_atanf128x = "";
pub const __DECL_SIMD_asin = "";
pub const __DECL_SIMD_asinf = "";
pub const __DECL_SIMD_asinl = "";
pub const __DECL_SIMD_asinf16 = "";
pub const __DECL_SIMD_asinf32 = "";
pub const __DECL_SIMD_asinf64 = "";
pub const __DECL_SIMD_asinf128 = "";
pub const __DECL_SIMD_asinf32x = "";
pub const __DECL_SIMD_asinf64x = "";
pub const __DECL_SIMD_asinf128x = "";
pub const __DECL_SIMD_hypot = "";
pub const __DECL_SIMD_hypotf = "";
pub const __DECL_SIMD_hypotl = "";
pub const __DECL_SIMD_hypotf16 = "";
pub const __DECL_SIMD_hypotf32 = "";
pub const __DECL_SIMD_hypotf64 = "";
pub const __DECL_SIMD_hypotf128 = "";
pub const __DECL_SIMD_hypotf32x = "";
pub const __DECL_SIMD_hypotf64x = "";
pub const __DECL_SIMD_hypotf128x = "";
pub const __DECL_SIMD_exp2 = "";
pub const __DECL_SIMD_exp2f = "";
pub const __DECL_SIMD_exp2l = "";
pub const __DECL_SIMD_exp2f16 = "";
pub const __DECL_SIMD_exp2f32 = "";
pub const __DECL_SIMD_exp2f64 = "";
pub const __DECL_SIMD_exp2f128 = "";
pub const __DECL_SIMD_exp2f32x = "";
pub const __DECL_SIMD_exp2f64x = "";
pub const __DECL_SIMD_exp2f128x = "";
pub const __DECL_SIMD_exp10 = "";
pub const __DECL_SIMD_exp10f = "";
pub const __DECL_SIMD_exp10l = "";
pub const __DECL_SIMD_exp10f16 = "";
pub const __DECL_SIMD_exp10f32 = "";
pub const __DECL_SIMD_exp10f64 = "";
pub const __DECL_SIMD_exp10f128 = "";
pub const __DECL_SIMD_exp10f32x = "";
pub const __DECL_SIMD_exp10f64x = "";
pub const __DECL_SIMD_exp10f128x = "";
pub const __DECL_SIMD_cosh = "";
pub const __DECL_SIMD_coshf = "";
pub const __DECL_SIMD_coshl = "";
pub const __DECL_SIMD_coshf16 = "";
pub const __DECL_SIMD_coshf32 = "";
pub const __DECL_SIMD_coshf64 = "";
pub const __DECL_SIMD_coshf128 = "";
pub const __DECL_SIMD_coshf32x = "";
pub const __DECL_SIMD_coshf64x = "";
pub const __DECL_SIMD_coshf128x = "";
pub const __DECL_SIMD_expm1 = "";
pub const __DECL_SIMD_expm1f = "";
pub const __DECL_SIMD_expm1l = "";
pub const __DECL_SIMD_expm1f16 = "";
pub const __DECL_SIMD_expm1f32 = "";
pub const __DECL_SIMD_expm1f64 = "";
pub const __DECL_SIMD_expm1f128 = "";
pub const __DECL_SIMD_expm1f32x = "";
pub const __DECL_SIMD_expm1f64x = "";
pub const __DECL_SIMD_expm1f128x = "";
pub const __DECL_SIMD_sinh = "";
pub const __DECL_SIMD_sinhf = "";
pub const __DECL_SIMD_sinhl = "";
pub const __DECL_SIMD_sinhf16 = "";
pub const __DECL_SIMD_sinhf32 = "";
pub const __DECL_SIMD_sinhf64 = "";
pub const __DECL_SIMD_sinhf128 = "";
pub const __DECL_SIMD_sinhf32x = "";
pub const __DECL_SIMD_sinhf64x = "";
pub const __DECL_SIMD_sinhf128x = "";
pub const __DECL_SIMD_cbrt = "";
pub const __DECL_SIMD_cbrtf = "";
pub const __DECL_SIMD_cbrtl = "";
pub const __DECL_SIMD_cbrtf16 = "";
pub const __DECL_SIMD_cbrtf32 = "";
pub const __DECL_SIMD_cbrtf64 = "";
pub const __DECL_SIMD_cbrtf128 = "";
pub const __DECL_SIMD_cbrtf32x = "";
pub const __DECL_SIMD_cbrtf64x = "";
pub const __DECL_SIMD_cbrtf128x = "";
pub const __DECL_SIMD_atan2 = "";
pub const __DECL_SIMD_atan2f = "";
pub const __DECL_SIMD_atan2l = "";
pub const __DECL_SIMD_atan2f16 = "";
pub const __DECL_SIMD_atan2f32 = "";
pub const __DECL_SIMD_atan2f64 = "";
pub const __DECL_SIMD_atan2f128 = "";
pub const __DECL_SIMD_atan2f32x = "";
pub const __DECL_SIMD_atan2f64x = "";
pub const __DECL_SIMD_atan2f128x = "";
pub const __DECL_SIMD_log10 = "";
pub const __DECL_SIMD_log10f = "";
pub const __DECL_SIMD_log10l = "";
pub const __DECL_SIMD_log10f16 = "";
pub const __DECL_SIMD_log10f32 = "";
pub const __DECL_SIMD_log10f64 = "";
pub const __DECL_SIMD_log10f128 = "";
pub const __DECL_SIMD_log10f32x = "";
pub const __DECL_SIMD_log10f64x = "";
pub const __DECL_SIMD_log10f128x = "";
pub const __DECL_SIMD_log2 = "";
pub const __DECL_SIMD_log2f = "";
pub const __DECL_SIMD_log2l = "";
pub const __DECL_SIMD_log2f16 = "";
pub const __DECL_SIMD_log2f32 = "";
pub const __DECL_SIMD_log2f64 = "";
pub const __DECL_SIMD_log2f128 = "";
pub const __DECL_SIMD_log2f32x = "";
pub const __DECL_SIMD_log2f64x = "";
pub const __DECL_SIMD_log2f128x = "";
pub const __DECL_SIMD_log1p = "";
pub const __DECL_SIMD_log1pf = "";
pub const __DECL_SIMD_log1pl = "";
pub const __DECL_SIMD_log1pf16 = "";
pub const __DECL_SIMD_log1pf32 = "";
pub const __DECL_SIMD_log1pf64 = "";
pub const __DECL_SIMD_log1pf128 = "";
pub const __DECL_SIMD_log1pf32x = "";
pub const __DECL_SIMD_log1pf64x = "";
pub const __DECL_SIMD_log1pf128x = "";
pub const __DECL_SIMD_atanh = "";
pub const __DECL_SIMD_atanhf = "";
pub const __DECL_SIMD_atanhl = "";
pub const __DECL_SIMD_atanhf16 = "";
pub const __DECL_SIMD_atanhf32 = "";
pub const __DECL_SIMD_atanhf64 = "";
pub const __DECL_SIMD_atanhf128 = "";
pub const __DECL_SIMD_atanhf32x = "";
pub const __DECL_SIMD_atanhf64x = "";
pub const __DECL_SIMD_atanhf128x = "";
pub const __DECL_SIMD_acosh = "";
pub const __DECL_SIMD_acoshf = "";
pub const __DECL_SIMD_acoshl = "";
pub const __DECL_SIMD_acoshf16 = "";
pub const __DECL_SIMD_acoshf32 = "";
pub const __DECL_SIMD_acoshf64 = "";
pub const __DECL_SIMD_acoshf128 = "";
pub const __DECL_SIMD_acoshf32x = "";
pub const __DECL_SIMD_acoshf64x = "";
pub const __DECL_SIMD_acoshf128x = "";
pub const __DECL_SIMD_erf = "";
pub const __DECL_SIMD_erff = "";
pub const __DECL_SIMD_erfl = "";
pub const __DECL_SIMD_erff16 = "";
pub const __DECL_SIMD_erff32 = "";
pub const __DECL_SIMD_erff64 = "";
pub const __DECL_SIMD_erff128 = "";
pub const __DECL_SIMD_erff32x = "";
pub const __DECL_SIMD_erff64x = "";
pub const __DECL_SIMD_erff128x = "";
pub const __DECL_SIMD_tanh = "";
pub const __DECL_SIMD_tanhf = "";
pub const __DECL_SIMD_tanhl = "";
pub const __DECL_SIMD_tanhf16 = "";
pub const __DECL_SIMD_tanhf32 = "";
pub const __DECL_SIMD_tanhf64 = "";
pub const __DECL_SIMD_tanhf128 = "";
pub const __DECL_SIMD_tanhf32x = "";
pub const __DECL_SIMD_tanhf64x = "";
pub const __DECL_SIMD_tanhf128x = "";
pub const __DECL_SIMD_asinh = "";
pub const __DECL_SIMD_asinhf = "";
pub const __DECL_SIMD_asinhl = "";
pub const __DECL_SIMD_asinhf16 = "";
pub const __DECL_SIMD_asinhf32 = "";
pub const __DECL_SIMD_asinhf64 = "";
pub const __DECL_SIMD_asinhf128 = "";
pub const __DECL_SIMD_asinhf32x = "";
pub const __DECL_SIMD_asinhf64x = "";
pub const __DECL_SIMD_asinhf128x = "";
pub const __DECL_SIMD_erfc = "";
pub const __DECL_SIMD_erfcf = "";
pub const __DECL_SIMD_erfcl = "";
pub const __DECL_SIMD_erfcf16 = "";
pub const __DECL_SIMD_erfcf32 = "";
pub const __DECL_SIMD_erfcf64 = "";
pub const __DECL_SIMD_erfcf128 = "";
pub const __DECL_SIMD_erfcf32x = "";
pub const __DECL_SIMD_erfcf64x = "";
pub const __DECL_SIMD_erfcf128x = "";
pub const __DECL_SIMD_tan = "";
pub const __DECL_SIMD_tanf = "";
pub const __DECL_SIMD_tanl = "";
pub const __DECL_SIMD_tanf16 = "";
pub const __DECL_SIMD_tanf32 = "";
pub const __DECL_SIMD_tanf64 = "";
pub const __DECL_SIMD_tanf128 = "";
pub const __DECL_SIMD_tanf32x = "";
pub const __DECL_SIMD_tanf64x = "";
pub const __DECL_SIMD_tanf128x = "";
pub const _BITS_FLOATN_H = "";
pub const __HAVE_FLOAT128 = @as(c_int, 1);
pub const __HAVE_DISTINCT_FLOAT128 = @as(c_int, 1);
pub const __HAVE_FLOAT64X = @as(c_int, 1);
pub const __HAVE_FLOAT64X_LONG_DOUBLE = @as(c_int, 1);
pub const __f128 = @compileError("unable to translate macro: undefined identifier `f128`"); // /usr/include/x86_64-linux-gnu/bits/floatn.h:65:12
pub const __CFLOAT128 = @compileError("unable to translate: invalid numeric type"); // /usr/include/x86_64-linux-gnu/bits/floatn.h:77:12
pub const _BITS_FLOATN_COMMON_H = "";
pub const __HAVE_FLOAT16 = @as(c_int, 0);
pub const __HAVE_FLOAT32 = @as(c_int, 1);
pub const __HAVE_FLOAT64 = @as(c_int, 1);
pub const __HAVE_FLOAT32X = @as(c_int, 1);
pub const __HAVE_FLOAT128X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT16 = __HAVE_FLOAT16;
pub const __HAVE_DISTINCT_FLOAT32 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT32X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT128X = __HAVE_FLOAT128X;
pub const __HAVE_FLOAT128_UNLIKE_LDBL = (__HAVE_DISTINCT_FLOAT128 != 0) and (__LDBL_MANT_DIG__ != @as(c_int, 113));
pub const __HAVE_FLOATN_NOT_TYPEDEF = @as(c_int, 1);
pub const __f32 = @compileError("unable to translate macro: undefined identifier `f32`"); // /usr/include/x86_64-linux-gnu/bits/floatn-common.h:93:12
pub const __f64 = @compileError("unable to translate macro: undefined identifier `f64`"); // /usr/include/x86_64-linux-gnu/bits/floatn-common.h:105:12
pub const __f32x = @compileError("unable to translate macro: undefined identifier `f32x`"); // /usr/include/x86_64-linux-gnu/bits/floatn-common.h:113:12
pub const __f64x = @compileError("unable to translate macro: undefined identifier `f64x`"); // /usr/include/x86_64-linux-gnu/bits/floatn-common.h:125:12
pub const __CFLOAT32 = @compileError("unable to translate: invalid numeric type"); // /usr/include/x86_64-linux-gnu/bits/floatn-common.h:151:12
pub const __CFLOAT64 = @compileError("unable to translate: invalid numeric type"); // /usr/include/x86_64-linux-gnu/bits/floatn-common.h:163:12
pub const __CFLOAT32X = @compileError("unable to translate: invalid numeric type"); // /usr/include/x86_64-linux-gnu/bits/floatn-common.h:171:12
pub const __CFLOAT64X = @compileError("unable to translate: invalid numeric type"); // /usr/include/x86_64-linux-gnu/bits/floatn-common.h:183:12
pub const HUGE_VAL = @compileError("unable to translate macro: undefined identifier `__builtin_huge_val`"); // /usr/include/math.h:48:10
pub const HUGE_VALF = __builtin.huge_valf();
pub const HUGE_VALL = @compileError("unable to translate macro: undefined identifier `__builtin_huge_vall`"); // /usr/include/math.h:60:11
pub const HUGE_VAL_F32 = @compileError("unable to translate macro: undefined identifier `__builtin_huge_valf32`"); // /usr/include/math.h:70:10
pub const HUGE_VAL_F64 = @compileError("unable to translate macro: undefined identifier `__builtin_huge_valf64`"); // /usr/include/math.h:73:10
pub const HUGE_VAL_F128 = @compileError("unable to translate macro: undefined identifier `__builtin_huge_valf128`"); // /usr/include/math.h:76:10
pub const HUGE_VAL_F32X = @compileError("unable to translate macro: undefined identifier `__builtin_huge_valf32x`"); // /usr/include/math.h:79:10
pub const HUGE_VAL_F64X = @compileError("unable to translate macro: undefined identifier `__builtin_huge_valf64x`"); // /usr/include/math.h:82:10
pub const INFINITY = __builtin.inff();
pub const NAN = __builtin.nanf("");
pub const SNANF = @compileError("unable to translate macro: undefined identifier `__builtin_nansf`"); // /usr/include/math.h:110:11
pub const SNAN = @compileError("unable to translate macro: undefined identifier `__builtin_nans`"); // /usr/include/math.h:111:11
pub const SNANL = @compileError("unable to translate macro: undefined identifier `__builtin_nansl`"); // /usr/include/math.h:112:11
pub const SNANF32 = @compileError("unable to translate macro: undefined identifier `__builtin_nansf32`"); // /usr/include/math.h:123:10
pub const SNANF64 = @compileError("unable to translate macro: undefined identifier `__builtin_nansf64`"); // /usr/include/math.h:128:10
pub const SNANF128 = @compileError("unable to translate macro: undefined identifier `__builtin_nansf128`"); // /usr/include/math.h:133:10
pub const SNANF32X = @compileError("unable to translate macro: undefined identifier `__builtin_nansf32x`"); // /usr/include/math.h:138:10
pub const SNANF64X = @compileError("unable to translate macro: undefined identifier `__builtin_nansf64x`"); // /usr/include/math.h:143:10
pub const __GLIBC_FLT_EVAL_METHOD = __FLT_EVAL_METHOD__;
pub const __FP_LOGB0_IS_MIN = @as(c_int, 1);
pub const __FP_LOGBNAN_IS_MIN = @as(c_int, 1);
pub const FP_ILOGB0 = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const FP_ILOGBNAN = -__helpers.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const __FP_LONG_MAX = __helpers.promoteIntLiteral(c_long, 0x7fffffffffffffff, .hex);
pub const FP_LLOGB0 = -__FP_LONG_MAX - @as(c_int, 1);
pub const FP_LLOGBNAN = -__FP_LONG_MAX - @as(c_int, 1);
pub const __SIMD_DECL = @compileError("unable to translate macro: undefined identifier `__DECL_SIMD_`"); // /usr/include/math.h:276:9
pub const __MATHCALL_VEC = @compileError("unable to translate macro: undefined identifier `__MATH_PRECNAME`"); // /usr/include/math.h:278:9
pub const __MATHDECL_VEC = @compileError("unable to translate macro: undefined identifier `__MATH_PRECNAME`"); // /usr/include/math.h:282:9
pub const __MATHCALLX = @compileError("unable to translate macro: undefined identifier `_Mdouble_`"); // /usr/include/math.h:291:9
pub const __MATHDECLX = @compileError("unable to translate macro: undefined identifier `__MATHDECL_1`"); // /usr/include/math.h:293:9
pub const __MATHREDIR = @compileError("unable to translate macro: undefined identifier `__MATH_PRECNAME`"); // /usr/include/math.h:305:9
pub const __MATH_DECLARE_LDOUBLE = @as(c_int, 1);
pub const __MATH_TG_F32 = @compileError("unable to translate macro: undefined identifier `f`"); // /usr/include/math.h:884:12
pub const __MATH_TG_F64X = @compileError("unable to translate macro: undefined identifier `l`"); // /usr/include/math.h:890:13
pub const __MATH_TG = @compileError("unable to translate macro: undefined identifier `f`"); // /usr/include/math.h:897:11
pub const fpclassify = @compileError("unable to translate macro: undefined identifier `__builtin_fpclassify`"); // /usr/include/math.h:967:11
pub inline fn signbit(x: anytype) @TypeOf(__builtin.signbit(x)) {
    _ = &x;
    return __builtin.signbit(x);
}
pub const isfinite = @compileError("unable to translate macro: undefined identifier `__builtin_isfinite`"); // /usr/include/math.h:994:11
pub const isnormal = @compileError("unable to translate macro: undefined identifier `__builtin_isnormal`"); // /usr/include/math.h:1002:11
pub const MATH_ERRNO = @as(c_int, 1);
pub const MATH_ERREXCEPT = @as(c_int, 2);
pub const math_errhandling = MATH_ERRNO | MATH_ERREXCEPT;
pub const __iscanonicalf = @compileError("unable to translate C expr: unexpected token '__typeof'"); // /usr/include/x86_64-linux-gnu/bits/iscanonical.h:25:9
pub const __iscanonical = @compileError("unable to translate C expr: unexpected token '__typeof'"); // /usr/include/x86_64-linux-gnu/bits/iscanonical.h:26:9
pub const __iscanonicalf128 = @compileError("unable to translate C expr: unexpected token '__typeof'"); // /usr/include/x86_64-linux-gnu/bits/iscanonical.h:28:10
pub inline fn iscanonical(x: anytype) @TypeOf(__MATH_TG(x, __iscanonical, x)) {
    _ = &x;
    return __MATH_TG(x, __iscanonical, x);
}
pub inline fn issignaling(x: anytype) @TypeOf(__MATH_TG(x, __issignaling, x)) {
    _ = &x;
    return __MATH_TG(x, __issignaling, x);
}
pub inline fn issubnormal(x: anytype) @TypeOf(fpclassify(x) == FP_SUBNORMAL) {
    _ = &x;
    return fpclassify(x) == FP_SUBNORMAL;
}
pub const iszero = @compileError("unable to translate C expr: unexpected token '__typeof'"); // /usr/include/math.h:1095:12
pub const MAXFLOAT = @as(f32, 3.40282347e+38);
pub const M_E = @as(f64, 2.7182818284590452354);
pub const M_LOG2E = @as(f64, 1.4426950408889634074);
pub const M_LOG10E = @as(f64, 0.43429448190325182765);
pub const M_LN2 = @as(f64, 0.69314718055994530942);
pub const M_LN10 = @as(f64, 2.30258509299404568402);
pub const M_PI = @as(f64, 3.14159265358979323846);
pub const M_PI_2 = @as(f64, 1.57079632679489661923);
pub const M_PI_4 = @as(f64, 0.78539816339744830962);
pub const M_1_PI = @as(f64, 0.31830988618379067154);
pub const M_2_PI = @as(f64, 0.63661977236758134308);
pub const M_2_SQRTPI = @as(f64, 1.12837916709551257390);
pub const M_SQRT2 = @as(f64, 1.41421356237309504880);
pub const M_SQRT1_2 = @as(f64, 0.70710678118654752440);
pub const M_Ef = @as(f32, 2.7182818284590452354);
pub const M_LOG2Ef = @as(f32, 1.4426950408889634074);
pub const M_LOG10Ef = @as(f32, 0.43429448190325182765);
pub const M_LN2f = @as(f32, 0.69314718055994530942);
pub const M_LN10f = @as(f32, 2.30258509299404568402);
pub const M_PIf = @as(f32, 3.14159265358979323846);
pub const M_PI_2f = @as(f32, 1.57079632679489661923);
pub const M_PI_4f = @as(f32, 0.78539816339744830962);
pub const M_1_PIf = @as(f32, 0.31830988618379067154);
pub const M_2_PIf = @as(f32, 0.63661977236758134308);
pub const M_2_SQRTPIf = @as(f32, 1.12837916709551257390);
pub const M_SQRT2f = @as(f32, 1.41421356237309504880);
pub const M_SQRT1_2f = @as(f32, 0.70710678118654752440);
pub const M_El = @as(c_longdouble, 2.718281828459045235360287471352662498);
pub const M_LOG2El = @as(c_longdouble, 1.442695040888963407359924681001892137);
pub const M_LOG10El = @as(c_longdouble, 0.434294481903251827651128918916605082);
pub const M_LN2l = @as(c_longdouble, 0.693147180559945309417232121458176568);
pub const M_LN10l = @as(c_longdouble, 2.302585092994045684017991454684364208);
pub const M_PIl = @as(c_longdouble, 3.141592653589793238462643383279502884);
pub const M_PI_2l = @as(c_longdouble, 1.570796326794896619231321691639751442);
pub const M_PI_4l = @as(c_longdouble, 0.785398163397448309615660845819875721);
pub const M_1_PIl = @as(c_longdouble, 0.318309886183790671537767526745028724);
pub const M_2_PIl = @as(c_longdouble, 0.636619772367581343075535053490057448);
pub const M_2_SQRTPIl = @as(c_longdouble, 1.128379167095512573896158903121545172);
pub const M_SQRT2l = @as(c_longdouble, 1.414213562373095048801688724209698079);
pub const M_SQRT1_2l = @as(c_longdouble, 0.707106781186547524400844362104849039);
pub const M_Ef32 = __f32(@as(f64, 2.718281828459045235360287471352662498));
pub const M_LOG2Ef32 = __f32(@as(f64, 1.442695040888963407359924681001892137));
pub const M_LOG10Ef32 = __f32(@as(f64, 0.434294481903251827651128918916605082));
pub const M_LN2f32 = __f32(@as(f64, 0.693147180559945309417232121458176568));
pub const M_LN10f32 = __f32(@as(f64, 2.302585092994045684017991454684364208));
pub const M_PIf32 = __f32(@as(f64, 3.141592653589793238462643383279502884));
pub const M_PI_2f32 = __f32(@as(f64, 1.570796326794896619231321691639751442));
pub const M_PI_4f32 = __f32(@as(f64, 0.785398163397448309615660845819875721));
pub const M_1_PIf32 = __f32(@as(f64, 0.318309886183790671537767526745028724));
pub const M_2_PIf32 = __f32(@as(f64, 0.636619772367581343075535053490057448));
pub const M_2_SQRTPIf32 = __f32(@as(f64, 1.128379167095512573896158903121545172));
pub const M_SQRT2f32 = __f32(@as(f64, 1.414213562373095048801688724209698079));
pub const M_SQRT1_2f32 = __f32(@as(f64, 0.707106781186547524400844362104849039));
pub const M_Ef64 = __f64(@as(f64, 2.718281828459045235360287471352662498));
pub const M_LOG2Ef64 = __f64(@as(f64, 1.442695040888963407359924681001892137));
pub const M_LOG10Ef64 = __f64(@as(f64, 0.434294481903251827651128918916605082));
pub const M_LN2f64 = __f64(@as(f64, 0.693147180559945309417232121458176568));
pub const M_LN10f64 = __f64(@as(f64, 2.302585092994045684017991454684364208));
pub const M_PIf64 = __f64(@as(f64, 3.141592653589793238462643383279502884));
pub const M_PI_2f64 = __f64(@as(f64, 1.570796326794896619231321691639751442));
pub const M_PI_4f64 = __f64(@as(f64, 0.785398163397448309615660845819875721));
pub const M_1_PIf64 = __f64(@as(f64, 0.318309886183790671537767526745028724));
pub const M_2_PIf64 = __f64(@as(f64, 0.636619772367581343075535053490057448));
pub const M_2_SQRTPIf64 = __f64(@as(f64, 1.128379167095512573896158903121545172));
pub const M_SQRT2f64 = __f64(@as(f64, 1.414213562373095048801688724209698079));
pub const M_SQRT1_2f64 = __f64(@as(f64, 0.707106781186547524400844362104849039));
pub const M_Ef128 = __f128(@as(f64, 2.718281828459045235360287471352662498));
pub const M_LOG2Ef128 = __f128(@as(f64, 1.442695040888963407359924681001892137));
pub const M_LOG10Ef128 = __f128(@as(f64, 0.434294481903251827651128918916605082));
pub const M_LN2f128 = __f128(@as(f64, 0.693147180559945309417232121458176568));
pub const M_LN10f128 = __f128(@as(f64, 2.302585092994045684017991454684364208));
pub const M_PIf128 = __f128(@as(f64, 3.141592653589793238462643383279502884));
pub const M_PI_2f128 = __f128(@as(f64, 1.570796326794896619231321691639751442));
pub const M_PI_4f128 = __f128(@as(f64, 0.785398163397448309615660845819875721));
pub const M_1_PIf128 = __f128(@as(f64, 0.318309886183790671537767526745028724));
pub const M_2_PIf128 = __f128(@as(f64, 0.636619772367581343075535053490057448));
pub const M_2_SQRTPIf128 = __f128(@as(f64, 1.128379167095512573896158903121545172));
pub const M_SQRT2f128 = __f128(@as(f64, 1.414213562373095048801688724209698079));
pub const M_SQRT1_2f128 = __f128(@as(f64, 0.707106781186547524400844362104849039));
pub const M_Ef32x = __f32x(@as(f64, 2.718281828459045235360287471352662498));
pub const M_LOG2Ef32x = __f32x(@as(f64, 1.442695040888963407359924681001892137));
pub const M_LOG10Ef32x = __f32x(@as(f64, 0.434294481903251827651128918916605082));
pub const M_LN2f32x = __f32x(@as(f64, 0.693147180559945309417232121458176568));
pub const M_LN10f32x = __f32x(@as(f64, 2.302585092994045684017991454684364208));
pub const M_PIf32x = __f32x(@as(f64, 3.141592653589793238462643383279502884));
pub const M_PI_2f32x = __f32x(@as(f64, 1.570796326794896619231321691639751442));
pub const M_PI_4f32x = __f32x(@as(f64, 0.785398163397448309615660845819875721));
pub const M_1_PIf32x = __f32x(@as(f64, 0.318309886183790671537767526745028724));
pub const M_2_PIf32x = __f32x(@as(f64, 0.636619772367581343075535053490057448));
pub const M_2_SQRTPIf32x = __f32x(@as(f64, 1.128379167095512573896158903121545172));
pub const M_SQRT2f32x = __f32x(@as(f64, 1.414213562373095048801688724209698079));
pub const M_SQRT1_2f32x = __f32x(@as(f64, 0.707106781186547524400844362104849039));
pub const M_Ef64x = __f64x(@as(f64, 2.718281828459045235360287471352662498));
pub const M_LOG2Ef64x = __f64x(@as(f64, 1.442695040888963407359924681001892137));
pub const M_LOG10Ef64x = __f64x(@as(f64, 0.434294481903251827651128918916605082));
pub const M_LN2f64x = __f64x(@as(f64, 0.693147180559945309417232121458176568));
pub const M_LN10f64x = __f64x(@as(f64, 2.302585092994045684017991454684364208));
pub const M_PIf64x = __f64x(@as(f64, 3.141592653589793238462643383279502884));
pub const M_PI_2f64x = __f64x(@as(f64, 1.570796326794896619231321691639751442));
pub const M_PI_4f64x = __f64x(@as(f64, 0.785398163397448309615660845819875721));
pub const M_1_PIf64x = __f64x(@as(f64, 0.318309886183790671537767526745028724));
pub const M_2_PIf64x = __f64x(@as(f64, 0.636619772367581343075535053490057448));
pub const M_2_SQRTPIf64x = __f64x(@as(f64, 1.128379167095512573896158903121545172));
pub const M_SQRT2f64x = __f64x(@as(f64, 1.414213562373095048801688724209698079));
pub const M_SQRT1_2f64x = __f64x(@as(f64, 0.707106781186547524400844362104849039));
pub const isgreater = @compileError("unable to translate macro: undefined identifier `__builtin_isgreater`"); // /usr/include/math.h:1306:11
pub const isgreaterequal = @compileError("unable to translate macro: undefined identifier `__builtin_isgreaterequal`"); // /usr/include/math.h:1307:11
pub const isless = @compileError("unable to translate macro: undefined identifier `__builtin_isless`"); // /usr/include/math.h:1308:11
pub const islessequal = @compileError("unable to translate macro: undefined identifier `__builtin_islessequal`"); // /usr/include/math.h:1309:11
pub const islessgreater = @compileError("unable to translate macro: undefined identifier `__builtin_islessgreater`"); // /usr/include/math.h:1310:11
pub const isunordered = @compileError("unable to translate macro: undefined identifier `__builtin_isunordered`"); // /usr/include/math.h:1311:11
pub inline fn __MATH_EVAL_FMT2(x: anytype, y: anytype) @TypeOf((x + y) + @as(f32, 0.0)) {
    _ = &x;
    _ = &y;
    return (x + y) + @as(f32, 0.0);
}
pub inline fn iseqsig(x: anytype, y: anytype) @TypeOf(__MATH_TG(__MATH_EVAL_FMT2(x, y), __iseqsig, blk_1: {
    _ = &x;
    break :blk_1 y;
})) {
    _ = &x;
    _ = &y;
    return __MATH_TG(__MATH_EVAL_FMT2(x, y), __iseqsig, blk_1: {
        _ = &x;
        break :blk_1 y;
    });
}
pub const __STDC_VERSION_STDARG_H__ = @as(c_int, 0);
pub const va_start = @compileError("unable to translate macro: undefined identifier `__builtin_va_start`"); // /home/fnn45/zig-x86_64-linux-0.16.0/lib/compiler/aro/include/stdarg.h:12:9
pub const va_end = @compileError("unable to translate macro: undefined identifier `__builtin_va_end`"); // /home/fnn45/zig-x86_64-linux-0.16.0/lib/compiler/aro/include/stdarg.h:14:9
pub const va_arg = @compileError("unable to translate macro: undefined identifier `__builtin_va_arg`"); // /home/fnn45/zig-x86_64-linux-0.16.0/lib/compiler/aro/include/stdarg.h:15:9
pub const __va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`"); // /home/fnn45/zig-x86_64-linux-0.16.0/lib/compiler/aro/include/stdarg.h:18:9
pub const va_copy = @compileError("unable to translate macro: undefined identifier `__builtin_va_copy`"); // /home/fnn45/zig-x86_64-linux-0.16.0/lib/compiler/aro/include/stdarg.h:22:9
pub const __GNUC_VA_LIST = @as(c_int, 1);
pub const _WCHAR_H = @as(c_int, 1);
pub const __need_size_t = "";
pub const __need_wchar_t = "";
pub const __need_NULL = "";
pub const __STDC_VERSION_STDDEF_H__ = @as(c_long, 202311);
pub const NULL = __helpers.cast(?*anyopaque, @as(c_int, 0));
pub const offsetof = @compileError("unable to translate macro: undefined identifier `__builtin_offsetof`"); // /home/fnn45/zig-x86_64-linux-0.16.0/lib/compiler/aro/include/stddef.h:18:9
pub const __need___va_list = "";
pub const _VA_LIST_DEFINED = "";
pub const __wint_t_defined = @as(c_int, 1);
pub const _WINT_T = @as(c_int, 1);
pub const __mbstate_t_defined = @as(c_int, 1);
pub const ____mbstate_t_defined = @as(c_int, 1);
pub const ____FILE_defined = @as(c_int, 1);
pub const __FILE_defined = @as(c_int, 1);
pub const _BITS_TYPES_LOCALE_T_H = @as(c_int, 1);
pub const _BITS_TYPES___LOCALE_T_H = @as(c_int, 1);
pub const WEOF = __helpers.promoteIntLiteral(c_uint, 0xffffffff, .hex);
pub const _SYS_TYPES_H = @as(c_int, 1);
pub const __u_char_defined = "";
pub const __ino_t_defined = "";
pub const __ino64_t_defined = "";
pub const __dev_t_defined = "";
pub const __gid_t_defined = "";
pub const __mode_t_defined = "";
pub const __nlink_t_defined = "";
pub const __uid_t_defined = "";
pub const __off_t_defined = "";
pub const __off64_t_defined = "";
pub const __pid_t_defined = "";
pub const __id_t_defined = "";
pub const __ssize_t_defined = "";
pub const __daddr_t_defined = "";
pub const __key_t_defined = "";
pub const __clock_t_defined = @as(c_int, 1);
pub const __clockid_t_defined = @as(c_int, 1);
pub const __time_t_defined = @as(c_int, 1);
pub const __timer_t_defined = @as(c_int, 1);
pub const __useconds_t_defined = "";
pub const __suseconds_t_defined = "";
pub const __BIT_TYPES_DEFINED__ = @as(c_int, 1);
pub const _ENDIAN_H = @as(c_int, 1);
pub const _BITS_ENDIAN_H = @as(c_int, 1);
pub const __LITTLE_ENDIAN = @as(c_int, 1234);
pub const __BIG_ENDIAN = @as(c_int, 4321);
pub const __PDP_ENDIAN = @as(c_int, 3412);
pub const _BITS_ENDIANNESS_H = @as(c_int, 1);
pub const __BYTE_ORDER = __LITTLE_ENDIAN;
pub const __FLOAT_WORD_ORDER = __BYTE_ORDER;
pub inline fn __LONG_LONG_PAIR(HI: anytype, LO: anytype) @TypeOf(HI) {
    _ = &HI;
    _ = &LO;
    return blk: {
        _ = &LO;
        break :blk HI;
    };
}
pub const LITTLE_ENDIAN = __LITTLE_ENDIAN;
pub const BIG_ENDIAN = __BIG_ENDIAN;
pub const PDP_ENDIAN = __PDP_ENDIAN;
pub const BYTE_ORDER = __BYTE_ORDER;
pub const _BITS_BYTESWAP_H = @as(c_int, 1);
pub inline fn __bswap_constant_16(x: anytype) __uint16_t {
    _ = &x;
    return __helpers.cast(__uint16_t, ((x >> @as(c_int, 8)) & @as(c_int, 0xff)) | ((x & @as(c_int, 0xff)) << @as(c_int, 8)));
}
pub inline fn __bswap_constant_32(x: anytype) @TypeOf(((((x & __helpers.promoteIntLiteral(c_uint, 0xff000000, .hex)) >> @as(c_int, 24)) | ((x & __helpers.promoteIntLiteral(c_uint, 0x00ff0000, .hex)) >> @as(c_int, 8))) | ((x & @as(c_uint, 0x0000ff00)) << @as(c_int, 8))) | ((x & @as(c_uint, 0x000000ff)) << @as(c_int, 24))) {
    _ = &x;
    return ((((x & __helpers.promoteIntLiteral(c_uint, 0xff000000, .hex)) >> @as(c_int, 24)) | ((x & __helpers.promoteIntLiteral(c_uint, 0x00ff0000, .hex)) >> @as(c_int, 8))) | ((x & @as(c_uint, 0x0000ff00)) << @as(c_int, 8))) | ((x & @as(c_uint, 0x000000ff)) << @as(c_int, 24));
}
pub inline fn __bswap_constant_64(x: anytype) @TypeOf(((((((((x & @as(c_ulonglong, 0xff00000000000000)) >> @as(c_int, 56)) | ((x & @as(c_ulonglong, 0x00ff000000000000)) >> @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x0000ff0000000000)) >> @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000ff00000000)) >> @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x00000000ff000000)) << @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x0000000000ff0000)) << @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000000000ff00)) << @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x00000000000000ff)) << @as(c_int, 56))) {
    _ = &x;
    return ((((((((x & @as(c_ulonglong, 0xff00000000000000)) >> @as(c_int, 56)) | ((x & @as(c_ulonglong, 0x00ff000000000000)) >> @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x0000ff0000000000)) >> @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000ff00000000)) >> @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x00000000ff000000)) << @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x0000000000ff0000)) << @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000000000ff00)) << @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x00000000000000ff)) << @as(c_int, 56));
}
pub const _BITS_UINTN_IDENTITY_H = @as(c_int, 1);
pub inline fn htobe16(x: anytype) @TypeOf(__bswap_16(x)) {
    _ = &x;
    return __bswap_16(x);
}
pub inline fn htole16(x: anytype) @TypeOf(__uint16_identity(x)) {
    _ = &x;
    return __uint16_identity(x);
}
pub inline fn be16toh(x: anytype) @TypeOf(__bswap_16(x)) {
    _ = &x;
    return __bswap_16(x);
}
pub inline fn le16toh(x: anytype) @TypeOf(__uint16_identity(x)) {
    _ = &x;
    return __uint16_identity(x);
}
pub inline fn htobe32(x: anytype) @TypeOf(__bswap_32(x)) {
    _ = &x;
    return __bswap_32(x);
}
pub inline fn htole32(x: anytype) @TypeOf(__uint32_identity(x)) {
    _ = &x;
    return __uint32_identity(x);
}
pub inline fn be32toh(x: anytype) @TypeOf(__bswap_32(x)) {
    _ = &x;
    return __bswap_32(x);
}
pub inline fn le32toh(x: anytype) @TypeOf(__uint32_identity(x)) {
    _ = &x;
    return __uint32_identity(x);
}
pub inline fn htobe64(x: anytype) @TypeOf(__bswap_64(x)) {
    _ = &x;
    return __bswap_64(x);
}
pub inline fn htole64(x: anytype) @TypeOf(__uint64_identity(x)) {
    _ = &x;
    return __uint64_identity(x);
}
pub inline fn be64toh(x: anytype) @TypeOf(__bswap_64(x)) {
    _ = &x;
    return __bswap_64(x);
}
pub inline fn le64toh(x: anytype) @TypeOf(__uint64_identity(x)) {
    _ = &x;
    return __uint64_identity(x);
}
pub const _SYS_SELECT_H = @as(c_int, 1);
pub const __FD_ZERO = @compileError("unable to translate macro: undefined identifier `__i`"); // /usr/include/x86_64-linux-gnu/bits/select.h:25:9
pub const __FD_SET = @compileError("unable to translate C expr: expected ')' instead got '|='"); // /usr/include/x86_64-linux-gnu/bits/select.h:32:9
pub const __FD_CLR = @compileError("unable to translate C expr: expected ')' instead got '&='"); // /usr/include/x86_64-linux-gnu/bits/select.h:34:9
pub inline fn __FD_ISSET(d: anytype, s: anytype) @TypeOf((__FDS_BITS(s)[@as(usize, @intCast(__FD_ELT(d)))] & __FD_MASK(d)) != @as(c_int, 0)) {
    _ = &d;
    _ = &s;
    return (__FDS_BITS(s)[@as(usize, @intCast(__FD_ELT(d)))] & __FD_MASK(d)) != @as(c_int, 0);
}
pub const __sigset_t_defined = @as(c_int, 1);
pub const ____sigset_t_defined = "";
pub const _SIGSET_NWORDS = __helpers.div(@as(c_int, 1024), @as(c_int, 8) * __helpers.sizeof(c_ulong));
pub const __timeval_defined = @as(c_int, 1);
pub const _STRUCT_TIMESPEC = @as(c_int, 1);
pub const __NFDBITS = @as(c_int, 8) * __helpers.cast(c_int, __helpers.sizeof(__fd_mask));
pub inline fn __FD_ELT(d: anytype) @TypeOf(__helpers.div(d, __NFDBITS)) {
    _ = &d;
    return __helpers.div(d, __NFDBITS);
}
pub inline fn __FD_MASK(d: anytype) __fd_mask {
    _ = &d;
    return __helpers.cast(__fd_mask, @as(c_ulong, 1) << __helpers.rem(d, __NFDBITS));
}
pub inline fn __FDS_BITS(set: anytype) @TypeOf(set.*.fds_bits) {
    _ = &set;
    return set.*.fds_bits;
}
pub const FD_SETSIZE = __FD_SETSIZE;
pub const NFDBITS = __NFDBITS;
pub inline fn FD_SET(fd: anytype, fdsetp: anytype) @TypeOf(__FD_SET(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_SET(fd, fdsetp);
}
pub inline fn FD_CLR(fd: anytype, fdsetp: anytype) @TypeOf(__FD_CLR(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_CLR(fd, fdsetp);
}
pub inline fn FD_ISSET(fd: anytype, fdsetp: anytype) @TypeOf(__FD_ISSET(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_ISSET(fd, fdsetp);
}
pub inline fn FD_ZERO(fdsetp: anytype) @TypeOf(__FD_ZERO(fdsetp)) {
    _ = &fdsetp;
    return __FD_ZERO(fdsetp);
}
pub const __blksize_t_defined = "";
pub const __blkcnt_t_defined = "";
pub const __fsblkcnt_t_defined = "";
pub const __fsfilcnt_t_defined = "";
pub const _BITS_PTHREADTYPES_COMMON_H = @as(c_int, 1);
pub const _THREAD_SHARED_TYPES_H = @as(c_int, 1);
pub const _BITS_PTHREADTYPES_ARCH_H = @as(c_int, 1);
pub const __SIZEOF_PTHREAD_MUTEX_T = @as(c_int, 40);
pub const __SIZEOF_PTHREAD_ATTR_T = @as(c_int, 56);
pub const __SIZEOF_PTHREAD_RWLOCK_T = @as(c_int, 56);
pub const __SIZEOF_PTHREAD_BARRIER_T = @as(c_int, 32);
pub const __SIZEOF_PTHREAD_MUTEXATTR_T = @as(c_int, 4);
pub const __SIZEOF_PTHREAD_COND_T = @as(c_int, 48);
pub const __SIZEOF_PTHREAD_CONDATTR_T = @as(c_int, 4);
pub const __SIZEOF_PTHREAD_RWLOCKATTR_T = @as(c_int, 8);
pub const __SIZEOF_PTHREAD_BARRIERATTR_T = @as(c_int, 4);
pub const __LOCK_ALIGNMENT = "";
pub const __ONCE_ALIGNMENT = "";
pub const _BITS_ATOMIC_WIDE_COUNTER_H = "";
pub const _THREAD_MUTEX_INTERNAL_H = @as(c_int, 1);
pub const __PTHREAD_MUTEX_HAVE_PREV = @as(c_int, 1);
pub const __PTHREAD_MUTEX_INITIALIZER = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/x86_64-linux-gnu/bits/struct_mutex.h:56:10
pub const _RWLOCK_INTERNAL_H = "";
pub const __PTHREAD_RWLOCK_ELISION_EXTRA = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/x86_64-linux-gnu/bits/struct_rwlock.h:40:11
pub inline fn __PTHREAD_RWLOCK_INITIALIZER(__flags: anytype) @TypeOf(__flags) {
    _ = &__flags;
    return blk: {
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = &__PTHREAD_RWLOCK_ELISION_EXTRA;
        _ = @as(c_int, 0);
        break :blk __flags;
    };
}
pub const __ONCE_FLAG_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/x86_64-linux-gnu/bits/thread-shared-types.h:113:9
pub const __have_pthread_attr_t = @as(c_int, 1);
pub const _ERRNO_H = @as(c_int, 1);
pub const _BITS_ERRNO_H = @as(c_int, 1);
pub const _ASM_GENERIC_ERRNO_H = "";
pub const _ASM_GENERIC_ERRNO_BASE_H = "";
pub const EPERM = @as(c_int, 1);
pub const ENOENT = @as(c_int, 2);
pub const ESRCH = @as(c_int, 3);
pub const EINTR = @as(c_int, 4);
pub const EIO = @as(c_int, 5);
pub const ENXIO = @as(c_int, 6);
pub const E2BIG = @as(c_int, 7);
pub const ENOEXEC = @as(c_int, 8);
pub const EBADF = @as(c_int, 9);
pub const ECHILD = @as(c_int, 10);
pub const EAGAIN = @as(c_int, 11);
pub const ENOMEM = @as(c_int, 12);
pub const EACCES = @as(c_int, 13);
pub const EFAULT = @as(c_int, 14);
pub const ENOTBLK = @as(c_int, 15);
pub const EBUSY = @as(c_int, 16);
pub const EEXIST = @as(c_int, 17);
pub const EXDEV = @as(c_int, 18);
pub const ENODEV = @as(c_int, 19);
pub const ENOTDIR = @as(c_int, 20);
pub const EISDIR = @as(c_int, 21);
pub const EINVAL = @as(c_int, 22);
pub const ENFILE = @as(c_int, 23);
pub const EMFILE = @as(c_int, 24);
pub const ENOTTY = @as(c_int, 25);
pub const ETXTBSY = @as(c_int, 26);
pub const EFBIG = @as(c_int, 27);
pub const ENOSPC = @as(c_int, 28);
pub const ESPIPE = @as(c_int, 29);
pub const EROFS = @as(c_int, 30);
pub const EMLINK = @as(c_int, 31);
pub const EPIPE = @as(c_int, 32);
pub const EDOM = @as(c_int, 33);
pub const ERANGE = @as(c_int, 34);
pub const EDEADLK = @as(c_int, 35);
pub const ENAMETOOLONG = @as(c_int, 36);
pub const ENOLCK = @as(c_int, 37);
pub const ENOSYS = @as(c_int, 38);
pub const ENOTEMPTY = @as(c_int, 39);
pub const ELOOP = @as(c_int, 40);
pub const EWOULDBLOCK = EAGAIN;
pub const ENOMSG = @as(c_int, 42);
pub const EIDRM = @as(c_int, 43);
pub const ECHRNG = @as(c_int, 44);
pub const EL2NSYNC = @as(c_int, 45);
pub const EL3HLT = @as(c_int, 46);
pub const EL3RST = @as(c_int, 47);
pub const ELNRNG = @as(c_int, 48);
pub const EUNATCH = @as(c_int, 49);
pub const ENOCSI = @as(c_int, 50);
pub const EL2HLT = @as(c_int, 51);
pub const EBADE = @as(c_int, 52);
pub const EBADR = @as(c_int, 53);
pub const EXFULL = @as(c_int, 54);
pub const ENOANO = @as(c_int, 55);
pub const EBADRQC = @as(c_int, 56);
pub const EBADSLT = @as(c_int, 57);
pub const EDEADLOCK = EDEADLK;
pub const EBFONT = @as(c_int, 59);
pub const ENOSTR = @as(c_int, 60);
pub const ENODATA = @as(c_int, 61);
pub const ETIME = @as(c_int, 62);
pub const ENOSR = @as(c_int, 63);
pub const ENONET = @as(c_int, 64);
pub const ENOPKG = @as(c_int, 65);
pub const EREMOTE = @as(c_int, 66);
pub const ENOLINK = @as(c_int, 67);
pub const EADV = @as(c_int, 68);
pub const ESRMNT = @as(c_int, 69);
pub const ECOMM = @as(c_int, 70);
pub const EPROTO = @as(c_int, 71);
pub const EMULTIHOP = @as(c_int, 72);
pub const EDOTDOT = @as(c_int, 73);
pub const EBADMSG = @as(c_int, 74);
pub const EOVERFLOW = @as(c_int, 75);
pub const ENOTUNIQ = @as(c_int, 76);
pub const EBADFD = @as(c_int, 77);
pub const EREMCHG = @as(c_int, 78);
pub const ELIBACC = @as(c_int, 79);
pub const ELIBBAD = @as(c_int, 80);
pub const ELIBSCN = @as(c_int, 81);
pub const ELIBMAX = @as(c_int, 82);
pub const ELIBEXEC = @as(c_int, 83);
pub const EILSEQ = @as(c_int, 84);
pub const ERESTART = @as(c_int, 85);
pub const ESTRPIPE = @as(c_int, 86);
pub const EUSERS = @as(c_int, 87);
pub const ENOTSOCK = @as(c_int, 88);
pub const EDESTADDRREQ = @as(c_int, 89);
pub const EMSGSIZE = @as(c_int, 90);
pub const EPROTOTYPE = @as(c_int, 91);
pub const ENOPROTOOPT = @as(c_int, 92);
pub const EPROTONOSUPPORT = @as(c_int, 93);
pub const ESOCKTNOSUPPORT = @as(c_int, 94);
pub const EOPNOTSUPP = @as(c_int, 95);
pub const EPFNOSUPPORT = @as(c_int, 96);
pub const EAFNOSUPPORT = @as(c_int, 97);
pub const EADDRINUSE = @as(c_int, 98);
pub const EADDRNOTAVAIL = @as(c_int, 99);
pub const ENETDOWN = @as(c_int, 100);
pub const ENETUNREACH = @as(c_int, 101);
pub const ENETRESET = @as(c_int, 102);
pub const ECONNABORTED = @as(c_int, 103);
pub const ECONNRESET = @as(c_int, 104);
pub const ENOBUFS = @as(c_int, 105);
pub const EISCONN = @as(c_int, 106);
pub const ENOTCONN = @as(c_int, 107);
pub const ESHUTDOWN = @as(c_int, 108);
pub const ETOOMANYREFS = @as(c_int, 109);
pub const ETIMEDOUT = @as(c_int, 110);
pub const ECONNREFUSED = @as(c_int, 111);
pub const EHOSTDOWN = @as(c_int, 112);
pub const EHOSTUNREACH = @as(c_int, 113);
pub const EALREADY = @as(c_int, 114);
pub const EINPROGRESS = @as(c_int, 115);
pub const ESTALE = @as(c_int, 116);
pub const EUCLEAN = @as(c_int, 117);
pub const ENOTNAM = @as(c_int, 118);
pub const ENAVAIL = @as(c_int, 119);
pub const EISNAM = @as(c_int, 120);
pub const EREMOTEIO = @as(c_int, 121);
pub const EDQUOT = @as(c_int, 122);
pub const ENOMEDIUM = @as(c_int, 123);
pub const EMEDIUMTYPE = @as(c_int, 124);
pub const ECANCELED = @as(c_int, 125);
pub const ENOKEY = @as(c_int, 126);
pub const EKEYEXPIRED = @as(c_int, 127);
pub const EKEYREVOKED = @as(c_int, 128);
pub const EKEYREJECTED = @as(c_int, 129);
pub const EOWNERDEAD = @as(c_int, 130);
pub const ENOTRECOVERABLE = @as(c_int, 131);
pub const ERFKILL = @as(c_int, 132);
pub const EHWPOISON = @as(c_int, 133);
pub const ENOTSUP = EOPNOTSUPP;
pub const errno = __errno_location().*;
pub const __error_t_defined = @as(c_int, 1);
pub const _STDIO_H = @as(c_int, 1);
pub const _____fpos_t_defined = @as(c_int, 1);
pub const _____fpos64_t_defined = @as(c_int, 1);
pub const __struct_FILE_defined = @as(c_int, 1);
pub const __getc_unlocked_body = @compileError("TODO postfix inc/dec expr"); // /usr/include/x86_64-linux-gnu/bits/types/struct_FILE.h:102:9
pub const __putc_unlocked_body = @compileError("TODO postfix inc/dec expr"); // /usr/include/x86_64-linux-gnu/bits/types/struct_FILE.h:106:9
pub const _IO_EOF_SEEN = @as(c_int, 0x0010);
pub inline fn __feof_unlocked_body(_fp: anytype) @TypeOf((_fp.*._flags & _IO_EOF_SEEN) != @as(c_int, 0)) {
    _ = &_fp;
    return (_fp.*._flags & _IO_EOF_SEEN) != @as(c_int, 0);
}
pub const _IO_ERR_SEEN = @as(c_int, 0x0020);
pub inline fn __ferror_unlocked_body(_fp: anytype) @TypeOf((_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0)) {
    _ = &_fp;
    return (_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0);
}
pub const _IO_USER_LOCK = __helpers.promoteIntLiteral(c_int, 0x8000, .hex);
pub const __cookie_io_functions_t_defined = @as(c_int, 1);
pub const _IOFBF = @as(c_int, 0);
pub const _IOLBF = @as(c_int, 1);
pub const _IONBF = @as(c_int, 2);
pub const BUFSIZ = @as(c_int, 8192);
pub const EOF = -@as(c_int, 1);
pub const SEEK_SET = @as(c_int, 0);
pub const SEEK_CUR = @as(c_int, 1);
pub const SEEK_END = @as(c_int, 2);
pub const SEEK_DATA = @as(c_int, 3);
pub const SEEK_HOLE = @as(c_int, 4);
pub const P_tmpdir = "/tmp";
pub const L_tmpnam = @as(c_int, 20);
pub const TMP_MAX = __helpers.promoteIntLiteral(c_int, 238328, .decimal);
pub const _BITS_STDIO_LIM_H = @as(c_int, 1);
pub const FILENAME_MAX = @as(c_int, 4096);
pub const L_ctermid = @as(c_int, 9);
pub const L_cuserid = @as(c_int, 9);
pub const FOPEN_MAX = @as(c_int, 16);
pub const _PRINTF_NAN_LEN_MAX = @as(c_int, 4);
pub const RENAME_NOREPLACE = @as(c_int, 1) << @as(c_int, 0);
pub const RENAME_EXCHANGE = @as(c_int, 1) << @as(c_int, 1);
pub const RENAME_WHITEOUT = @as(c_int, 1) << @as(c_int, 2);
pub const __attr_dealloc_fclose = __attr_dealloc(fclose, @as(c_int, 1));
pub const _BITS_STDIO_H = @as(c_int, 1);
pub const _STDLIB_H = @as(c_int, 1);
pub const WNOHANG = @as(c_int, 1);
pub const WUNTRACED = @as(c_int, 2);
pub const WSTOPPED = @as(c_int, 2);
pub const WEXITED = @as(c_int, 4);
pub const WCONTINUED = @as(c_int, 8);
pub const WNOWAIT = __helpers.promoteIntLiteral(c_int, 0x01000000, .hex);
pub const __WNOTHREAD = __helpers.promoteIntLiteral(c_int, 0x20000000, .hex);
pub const __WALL = __helpers.promoteIntLiteral(c_int, 0x40000000, .hex);
pub const __WCLONE = __helpers.promoteIntLiteral(c_int, 0x80000000, .hex);
pub inline fn __WEXITSTATUS(status: anytype) @TypeOf((status & __helpers.promoteIntLiteral(c_int, 0xff00, .hex)) >> @as(c_int, 8)) {
    _ = &status;
    return (status & __helpers.promoteIntLiteral(c_int, 0xff00, .hex)) >> @as(c_int, 8);
}
pub inline fn __WTERMSIG(status: anytype) @TypeOf(status & @as(c_int, 0x7f)) {
    _ = &status;
    return status & @as(c_int, 0x7f);
}
pub inline fn __WSTOPSIG(status: anytype) @TypeOf(__WEXITSTATUS(status)) {
    _ = &status;
    return __WEXITSTATUS(status);
}
pub inline fn __WIFEXITED(status: anytype) @TypeOf(__WTERMSIG(status) == @as(c_int, 0)) {
    _ = &status;
    return __WTERMSIG(status) == @as(c_int, 0);
}
pub inline fn __WIFSIGNALED(status: anytype) @TypeOf((__helpers.cast(i8, (status & @as(c_int, 0x7f)) + @as(c_int, 1)) >> @as(c_int, 1)) > @as(c_int, 0)) {
    _ = &status;
    return (__helpers.cast(i8, (status & @as(c_int, 0x7f)) + @as(c_int, 1)) >> @as(c_int, 1)) > @as(c_int, 0);
}
pub inline fn __WIFSTOPPED(status: anytype) @TypeOf((status & @as(c_int, 0xff)) == @as(c_int, 0x7f)) {
    _ = &status;
    return (status & @as(c_int, 0xff)) == @as(c_int, 0x7f);
}
pub inline fn __WIFCONTINUED(status: anytype) @TypeOf(status == __W_CONTINUED) {
    _ = &status;
    return status == __W_CONTINUED;
}
pub inline fn __WCOREDUMP(status: anytype) @TypeOf(status & __WCOREFLAG) {
    _ = &status;
    return status & __WCOREFLAG;
}
pub inline fn __W_EXITCODE(ret: anytype, sig: anytype) @TypeOf((ret << @as(c_int, 8)) | sig) {
    _ = &ret;
    _ = &sig;
    return (ret << @as(c_int, 8)) | sig;
}
pub inline fn __W_STOPCODE(sig: anytype) @TypeOf((sig << @as(c_int, 8)) | @as(c_int, 0x7f)) {
    _ = &sig;
    return (sig << @as(c_int, 8)) | @as(c_int, 0x7f);
}
pub const __W_CONTINUED = __helpers.promoteIntLiteral(c_int, 0xffff, .hex);
pub const __WCOREFLAG = @as(c_int, 0x80);
pub inline fn WEXITSTATUS(status: anytype) @TypeOf(__WEXITSTATUS(status)) {
    _ = &status;
    return __WEXITSTATUS(status);
}
pub inline fn WTERMSIG(status: anytype) @TypeOf(__WTERMSIG(status)) {
    _ = &status;
    return __WTERMSIG(status);
}
pub inline fn WSTOPSIG(status: anytype) @TypeOf(__WSTOPSIG(status)) {
    _ = &status;
    return __WSTOPSIG(status);
}
pub inline fn WIFEXITED(status: anytype) @TypeOf(__WIFEXITED(status)) {
    _ = &status;
    return __WIFEXITED(status);
}
pub inline fn WIFSIGNALED(status: anytype) @TypeOf(__WIFSIGNALED(status)) {
    _ = &status;
    return __WIFSIGNALED(status);
}
pub inline fn WIFSTOPPED(status: anytype) @TypeOf(__WIFSTOPPED(status)) {
    _ = &status;
    return __WIFSTOPPED(status);
}
pub inline fn WIFCONTINUED(status: anytype) @TypeOf(__WIFCONTINUED(status)) {
    _ = &status;
    return __WIFCONTINUED(status);
}
pub const __ldiv_t_defined = @as(c_int, 1);
pub const __lldiv_t_defined = @as(c_int, 1);
pub const RAND_MAX = __helpers.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const EXIT_FAILURE = @as(c_int, 1);
pub const EXIT_SUCCESS = @as(c_int, 0);
pub const MB_CUR_MAX = __ctype_get_mb_cur_max();
pub const _ALLOCA_H = @as(c_int, 1);
pub const __COMPAR_FN_T = "";
pub const _STRING_H = @as(c_int, 1);
pub const __GLIBC_USE_LIB_EXT2 = @as(c_int, 1);
pub const __GLIBC_USE_IEC_60559_BFP_EXT = @as(c_int, 1);
pub const __GLIBC_USE_IEC_60559_BFP_EXT_C2X = @as(c_int, 1);
pub const __GLIBC_USE_IEC_60559_EXT = @as(c_int, 1);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT = @as(c_int, 1);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT_C2X = @as(c_int, 1);
pub const __GLIBC_USE_IEC_60559_TYPES_EXT = @as(c_int, 1);
pub const strdupa = @compileError("unable to translate macro: undefined identifier `__old`"); // /usr/include/string.h:201:10
pub const strndupa = @compileError("unable to translate macro: undefined identifier `__old`"); // /usr/include/string.h:211:10
pub const _STRINGS_H = @as(c_int, 1);
pub const _CTYPE_H = @as(c_int, 1);
pub inline fn _ISbit(bit: anytype) @TypeOf(if (__helpers.cast(bool, bit < @as(c_int, 8))) (@as(c_int, 1) << bit) << @as(c_int, 8) else (@as(c_int, 1) << bit) >> @as(c_int, 8)) {
    _ = &bit;
    return if (__helpers.cast(bool, bit < @as(c_int, 8))) (@as(c_int, 1) << bit) << @as(c_int, 8) else (@as(c_int, 1) << bit) >> @as(c_int, 8);
}
pub inline fn __isctype(c: anytype, @"type": anytype) @TypeOf(__ctype_b_loc().*[@as(usize, @intCast(__helpers.cast(c_int, c)))] & __helpers.cast(c_ushort, @"type")) {
    _ = &c;
    _ = &@"type";
    return __ctype_b_loc().*[@as(usize, @intCast(__helpers.cast(c_int, c)))] & __helpers.cast(c_ushort, @"type");
}
pub inline fn __isascii(c: anytype) @TypeOf((c & ~@as(c_int, 0x7f)) == @as(c_int, 0)) {
    _ = &c;
    return (c & ~@as(c_int, 0x7f)) == @as(c_int, 0);
}
pub inline fn __toascii(c: anytype) @TypeOf(c & @as(c_int, 0x7f)) {
    _ = &c;
    return c & @as(c_int, 0x7f);
}
pub const __exctype = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/ctype.h:102:9
pub const __tobody = @compileError("unable to translate macro: undefined identifier `__res`"); // /usr/include/ctype.h:155:9
pub inline fn __isctype_l(c: anytype, @"type": anytype, locale: anytype) @TypeOf(locale.*.__ctype_b[@as(usize, @intCast(__helpers.cast(c_int, c)))] & __helpers.cast(c_ushort, @"type")) {
    _ = &c;
    _ = &@"type";
    _ = &locale;
    return locale.*.__ctype_b[@as(usize, @intCast(__helpers.cast(c_int, c)))] & __helpers.cast(c_ushort, @"type");
}
pub const __exctype_l = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/ctype.h:244:10
pub inline fn __isalnum_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISalnum, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISalnum, l);
}
pub inline fn __isalpha_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISalpha, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISalpha, l);
}
pub inline fn __iscntrl_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _IScntrl, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _IScntrl, l);
}
pub inline fn __isdigit_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISdigit, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISdigit, l);
}
pub inline fn __islower_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISlower, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISlower, l);
}
pub inline fn __isgraph_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISgraph, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISgraph, l);
}
pub inline fn __isprint_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISprint, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISprint, l);
}
pub inline fn __ispunct_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISpunct, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISpunct, l);
}
pub inline fn __isspace_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISspace, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISspace, l);
}
pub inline fn __isupper_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISupper, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISupper, l);
}
pub inline fn __isxdigit_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISxdigit, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISxdigit, l);
}
pub inline fn __isblank_l(c: anytype, l: anytype) @TypeOf(__isctype_l(c, _ISblank, l)) {
    _ = &c;
    _ = &l;
    return __isctype_l(c, _ISblank, l);
}
pub inline fn __isascii_l(c: anytype, l: anytype) @TypeOf(__isascii(c)) {
    _ = &c;
    _ = &l;
    return blk_1: {
        _ = &l;
        break :blk_1 __isascii(c);
    };
}
pub inline fn __toascii_l(c: anytype, l: anytype) @TypeOf(__toascii(c)) {
    _ = &c;
    _ = &l;
    return blk_1: {
        _ = &l;
        break :blk_1 __toascii(c);
    };
}
pub inline fn isascii_l(c: anytype, l: anytype) @TypeOf(__isascii_l(c, l)) {
    _ = &c;
    _ = &l;
    return __isascii_l(c, l);
}
pub inline fn toascii_l(c: anytype, l: anytype) @TypeOf(__toascii_l(c, l)) {
    _ = &c;
    _ = &l;
    return __toascii_l(c, l);
}
pub const _UNISTD_H = @as(c_int, 1);
pub const _POSIX_VERSION = @as(c_long, 200809);
pub const __POSIX2_THIS_VERSION = @as(c_long, 200809);
pub const _POSIX2_VERSION = __POSIX2_THIS_VERSION;
pub const _POSIX2_C_VERSION = __POSIX2_THIS_VERSION;
pub const _POSIX2_C_BIND = __POSIX2_THIS_VERSION;
pub const _POSIX2_C_DEV = __POSIX2_THIS_VERSION;
pub const _POSIX2_SW_DEV = __POSIX2_THIS_VERSION;
pub const _POSIX2_LOCALEDEF = __POSIX2_THIS_VERSION;
pub const _XOPEN_VERSION = @as(c_int, 700);
pub const _XOPEN_XCU_VERSION = @as(c_int, 4);
pub const _XOPEN_XPG2 = @as(c_int, 1);
pub const _XOPEN_XPG3 = @as(c_int, 1);
pub const _XOPEN_XPG4 = @as(c_int, 1);
pub const _XOPEN_UNIX = @as(c_int, 1);
pub const _XOPEN_ENH_I18N = @as(c_int, 1);
pub const _XOPEN_LEGACY = @as(c_int, 1);
pub const _BITS_POSIX_OPT_H = @as(c_int, 1);
pub const _POSIX_JOB_CONTROL = @as(c_int, 1);
pub const _POSIX_SAVED_IDS = @as(c_int, 1);
pub const _POSIX_PRIORITY_SCHEDULING = @as(c_long, 200809);
pub const _POSIX_SYNCHRONIZED_IO = @as(c_long, 200809);
pub const _POSIX_FSYNC = @as(c_long, 200809);
pub const _POSIX_MAPPED_FILES = @as(c_long, 200809);
pub const _POSIX_MEMLOCK = @as(c_long, 200809);
pub const _POSIX_MEMLOCK_RANGE = @as(c_long, 200809);
pub const _POSIX_MEMORY_PROTECTION = @as(c_long, 200809);
pub const _POSIX_CHOWN_RESTRICTED = @as(c_int, 0);
pub const _POSIX_VDISABLE = '\x00';
pub const _POSIX_NO_TRUNC = @as(c_int, 1);
pub const _XOPEN_REALTIME = @as(c_int, 1);
pub const _XOPEN_REALTIME_THREADS = @as(c_int, 1);
pub const _XOPEN_SHM = @as(c_int, 1);
pub const _POSIX_THREADS = @as(c_long, 200809);
pub const _POSIX_REENTRANT_FUNCTIONS = @as(c_int, 1);
pub const _POSIX_THREAD_SAFE_FUNCTIONS = @as(c_long, 200809);
pub const _POSIX_THREAD_PRIORITY_SCHEDULING = @as(c_long, 200809);
pub const _POSIX_THREAD_ATTR_STACKSIZE = @as(c_long, 200809);
pub const _POSIX_THREAD_ATTR_STACKADDR = @as(c_long, 200809);
pub const _POSIX_THREAD_PRIO_INHERIT = @as(c_long, 200809);
pub const _POSIX_THREAD_PRIO_PROTECT = @as(c_long, 200809);
pub const _POSIX_THREAD_ROBUST_PRIO_INHERIT = @as(c_long, 200809);
pub const _POSIX_THREAD_ROBUST_PRIO_PROTECT = -@as(c_int, 1);
pub const _POSIX_SEMAPHORES = @as(c_long, 200809);
pub const _POSIX_REALTIME_SIGNALS = @as(c_long, 200809);
pub const _POSIX_ASYNCHRONOUS_IO = @as(c_long, 200809);
pub const _POSIX_ASYNC_IO = @as(c_int, 1);
pub const _LFS_ASYNCHRONOUS_IO = @as(c_int, 1);
pub const _POSIX_PRIORITIZED_IO = @as(c_long, 200809);
pub const _LFS64_ASYNCHRONOUS_IO = @as(c_int, 1);
pub const _LFS_LARGEFILE = @as(c_int, 1);
pub const _LFS64_LARGEFILE = @as(c_int, 1);
pub const _LFS64_STDIO = @as(c_int, 1);
pub const _POSIX_SHARED_MEMORY_OBJECTS = @as(c_long, 200809);
pub const _POSIX_CPUTIME = @as(c_int, 0);
pub const _POSIX_THREAD_CPUTIME = @as(c_int, 0);
pub const _POSIX_REGEXP = @as(c_int, 1);
pub const _POSIX_READER_WRITER_LOCKS = @as(c_long, 200809);
pub const _POSIX_SHELL = @as(c_int, 1);
pub const _POSIX_TIMEOUTS = @as(c_long, 200809);
pub const _POSIX_SPIN_LOCKS = @as(c_long, 200809);
pub const _POSIX_SPAWN = @as(c_long, 200809);
pub const _POSIX_TIMERS = @as(c_long, 200809);
pub const _POSIX_BARRIERS = @as(c_long, 200809);
pub const _POSIX_MESSAGE_PASSING = @as(c_long, 200809);
pub const _POSIX_THREAD_PROCESS_SHARED = @as(c_long, 200809);
pub const _POSIX_MONOTONIC_CLOCK = @as(c_int, 0);
pub const _POSIX_CLOCK_SELECTION = @as(c_long, 200809);
pub const _POSIX_ADVISORY_INFO = @as(c_long, 200809);
pub const _POSIX_IPV6 = @as(c_long, 200809);
pub const _POSIX_RAW_SOCKETS = @as(c_long, 200809);
pub const _POSIX2_CHAR_TERM = @as(c_long, 200809);
pub const _POSIX_SPORADIC_SERVER = -@as(c_int, 1);
pub const _POSIX_THREAD_SPORADIC_SERVER = -@as(c_int, 1);
pub const _POSIX_TRACE = -@as(c_int, 1);
pub const _POSIX_TRACE_EVENT_FILTER = -@as(c_int, 1);
pub const _POSIX_TRACE_INHERIT = -@as(c_int, 1);
pub const _POSIX_TRACE_LOG = -@as(c_int, 1);
pub const _POSIX_TYPED_MEMORY_OBJECTS = -@as(c_int, 1);
pub const _POSIX_V7_LPBIG_OFFBIG = -@as(c_int, 1);
pub const _POSIX_V6_LPBIG_OFFBIG = -@as(c_int, 1);
pub const _XBS5_LPBIG_OFFBIG = -@as(c_int, 1);
pub const _POSIX_V7_LP64_OFF64 = @as(c_int, 1);
pub const _POSIX_V6_LP64_OFF64 = @as(c_int, 1);
pub const _XBS5_LP64_OFF64 = @as(c_int, 1);
pub const __ILP32_OFF32_CFLAGS = "-m32";
pub const __ILP32_OFF32_LDFLAGS = "-m32";
pub const __ILP32_OFFBIG_CFLAGS = "-m32 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64";
pub const __ILP32_OFFBIG_LDFLAGS = "-m32";
pub const __LP64_OFF64_CFLAGS = "-m64";
pub const __LP64_OFF64_LDFLAGS = "-m64";
pub const STDIN_FILENO = @as(c_int, 0);
pub const STDOUT_FILENO = @as(c_int, 1);
pub const STDERR_FILENO = @as(c_int, 2);
pub const __socklen_t_defined = "";
pub const R_OK = @as(c_int, 4);
pub const W_OK = @as(c_int, 2);
pub const X_OK = @as(c_int, 1);
pub const F_OK = @as(c_int, 0);
pub const L_SET = SEEK_SET;
pub const L_INCR = SEEK_CUR;
pub const L_XTND = SEEK_END;
pub const _SC_PAGE_SIZE = _SC_PAGESIZE;
pub const _CS_POSIX_V6_WIDTH_RESTRICTED_ENVS = _CS_V6_WIDTH_RESTRICTED_ENVS;
pub const _CS_POSIX_V5_WIDTH_RESTRICTED_ENVS = _CS_V5_WIDTH_RESTRICTED_ENVS;
pub const _CS_POSIX_V7_WIDTH_RESTRICTED_ENVS = _CS_V7_WIDTH_RESTRICTED_ENVS;
pub const _GETOPT_POSIX_H = @as(c_int, 1);
pub const _GETOPT_CORE_H = @as(c_int, 1);
pub const F_ULOCK = @as(c_int, 0);
pub const F_LOCK = @as(c_int, 1);
pub const F_TLOCK = @as(c_int, 2);
pub const F_TEST = @as(c_int, 3);
pub const TEMP_FAILURE_RETRY = @compileError("unable to translate macro: undefined identifier `__result`"); // /usr/include/unistd.h:1134:10
pub const _LINUX_CLOSE_RANGE_H = "";
pub const CLOSE_RANGE_UNSHARE = @as(c_uint, 1) << @as(c_int, 1);
pub const CLOSE_RANGE_CLOEXEC = @as(c_uint, 1) << @as(c_int, 2);
pub const Py_PYPORT_H = "";
pub inline fn _Py__has_builtin(x: anytype) @TypeOf(__builtin.has_builtin(x)) {
    _ = &x;
    return __builtin.has_builtin(x);
}
pub const _Py__has_attribute = @compileError("unable to translate macro: undefined identifier `__has_attribute`"); // /usr/include/python3.14/pyport.h:25:11
pub const _Py_STATIC_CAST = __helpers.CAST_OR_CALL;
pub const _Py_CAST = __helpers.CAST_OR_CALL;
pub const _Py_FUNC_CAST = @compileError("unable to translate C expr: unexpected token ')'"); // /usr/include/python3.14/pyport.h:47:9
pub const _Py_NULL = NULL;
pub const HAVE_LONG_LONG = @as(c_int, 1);
pub const PY_LONG_LONG = c_longlong;
pub const PY_LLONG_MIN = LLONG_MIN;
pub const PY_LLONG_MAX = LLONG_MAX;
pub const PY_ULLONG_MAX = ULLONG_MAX;
pub const PY_UINT32_T = u32;
pub const PY_UINT64_T = u64;
pub const PY_INT32_T = i32;
pub const PY_INT64_T = i64;
pub const PYLONG_BITS_IN_DIGIT = @as(c_int, 30);
pub const PY_SSIZE_T_MAX = SSIZE_MAX;
pub const PY_SSIZE_T_MIN = -PY_SSIZE_T_MAX - @as(c_int, 1);
pub const SIZEOF_PY_HASH_T = SIZEOF_SIZE_T;
pub const SIZEOF_PY_UHASH_T = SIZEOF_SIZE_T;
pub const PY_SIZE_MAX = SIZE_MAX;
pub const PY_FORMAT_SIZE_T = "z";
pub const Py_LOCAL = @compileError("unable to translate C expr: unexpected token 'static'"); // /usr/include/python3.14/pyport.h:208:11
pub const Py_LOCAL_INLINE = @compileError("unable to translate C expr: unexpected token 'static'"); // /usr/include/python3.14/pyport.h:209:11
pub const Py_MEMCPY = memcpy;
pub inline fn Py_ARITHMETIC_RIGHT_SHIFT(TYPE: anytype, I: anytype, J: anytype) @TypeOf(I >> J) {
    _ = &TYPE;
    _ = &I;
    _ = &J;
    return I >> J;
}
pub inline fn Py_FORCE_EXPANSION(X: anytype) @TypeOf(X) {
    _ = &X;
    return X;
}
pub inline fn Py_SAFE_DOWNCAST(VALUE: anytype, WIDE: anytype, NARROW: anytype) @TypeOf(_Py_STATIC_CAST(NARROW, VALUE)) {
    _ = &VALUE;
    _ = &WIDE;
    _ = &NARROW;
    return _Py_STATIC_CAST(NARROW, VALUE);
}
pub const Py_DEPRECATED = @compileError("unable to translate macro: undefined identifier `__deprecated__`"); // /usr/include/python3.14/pyport.h:281:9
pub inline fn _Py_DEPRECATED_EXTERNALLY(version: anytype) @TypeOf(Py_DEPRECATED(version)) {
    _ = &version;
    return Py_DEPRECATED(version);
}
pub const _Py_COMP_DIAG_PUSH = @compileError("unable to translate macro: undefined identifier `_Pragma`"); // /usr/include/python3.14/pyport.h:305:9
pub const _Py_COMP_DIAG_IGNORE_DEPR_DECLS = @compileError("unable to translate macro: undefined identifier `_Pragma`"); // /usr/include/python3.14/pyport.h:306:9
pub const _Py_COMP_DIAG_POP = @compileError("unable to translate macro: undefined identifier `_Pragma`"); // /usr/include/python3.14/pyport.h:308:9
pub const _Py_HOT_FUNCTION = @compileError("unable to translate macro: undefined identifier `hot`"); // /usr/include/python3.14/pyport.h:336:9
pub const Py_ALWAYS_INLINE = @compileError("unable to translate macro: undefined identifier `always_inline`"); // /usr/include/python3.14/pyport.h:365:11
pub const Py_NO_INLINE = @compileError("unable to translate macro: undefined identifier `noinline`"); // /usr/include/python3.14/pyport.h:381:11
pub const Py_EXPORTS_H = "";
pub const Py_IMPORTED_SYMBOL = @compileError("unable to translate macro: undefined identifier `visibility`"); // /usr/include/python3.14/exports.h:46:17
pub const Py_EXPORTED_SYMBOL = @compileError("unable to translate macro: undefined identifier `visibility`"); // /usr/include/python3.14/exports.h:47:17
pub const Py_LOCAL_SYMBOL = @compileError("unable to translate macro: undefined identifier `visibility`"); // /usr/include/python3.14/exports.h:48:17
pub inline fn PyAPI_FUNC(RTYPE: anytype) @TypeOf(Py_EXPORTED_SYMBOL ++ RTYPE) {
    _ = &RTYPE;
    return Py_EXPORTED_SYMBOL ++ RTYPE;
}
pub const PyAPI_DATA = @compileError("unable to translate C expr: unexpected token 'extern'"); // /usr/include/python3.14/exports.h:94:16
pub const PyMODINIT_FUNC = [*c](Py_EXPORTED_SYMBOL ++ PyObject);
pub const Py_GCC_ATTRIBUTE = @compileError("unable to translate C expr: unexpected token '__attribute__'"); // /usr/include/python3.14/pyport.h:443:9
pub const Py_ALIGNED = @compileError("unable to translate macro: undefined identifier `aligned`"); // /usr/include/python3.14/pyport.h:450:9
pub const Py_LL = __helpers.LL_SUFFIX;
pub const Py_ULL = @compileError("unable to translate macro: undefined identifier `U`"); // /usr/include/python3.14/pyport.h:467:9
pub const Py_VA_COPY = va_copy;
pub const PY_BIG_ENDIAN = @as(c_int, 0);
pub const PY_LITTLE_ENDIAN = @as(c_int, 1);
pub const PY_DWORD_MAX = __helpers.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const WITH_THREAD = "";
pub const Py_CAN_START_THREADS = @as(c_int, 1);
pub const _Py_NO_RETURN = @compileError("unable to translate macro: undefined identifier `__noreturn__`"); // /usr/include/python3.14/pyport.h:555:11
pub const _Py_TYPEOF = @compileError("unable to translate C expr: unexpected token '__typeof__'"); // /usr/include/python3.14/pyport.h:570:11
pub const _Py_NO_SANITIZE_ADDRESS = "";
pub const _Py_NO_SANITIZE_THREAD = "";
pub const _Py_NO_SANITIZE_MEMORY = "";
pub const PY_CXX_CONST = "";
pub const _Py_FALLTHROUGH = @compileError("unable to translate macro: undefined identifier `fallthrough`"); // /usr/include/python3.14/pyport.h:664:11
pub const _Py_NO_SANITIZE_UNDEFINED = @compileError("unable to translate macro: undefined identifier `no_sanitize_undefined`"); // /usr/include/python3.14/pyport.h:682:11
pub const _Py_NONSTRING = @compileError("unable to translate macro: undefined identifier `nonstring`"); // /usr/include/python3.14/pyport.h:698:11
pub const Py_PYMACRO_H = "";
pub inline fn Py_MIN(x: anytype, y: anytype) @TypeOf(if (__helpers.cast(bool, x > y)) y else x) {
    _ = &x;
    _ = &y;
    return if (__helpers.cast(bool, x > y)) y else x;
}
pub inline fn Py_MAX(x: anytype, y: anytype) @TypeOf(if (__helpers.cast(bool, x > y)) x else y) {
    _ = &x;
    _ = &y;
    return if (__helpers.cast(bool, x > y)) x else y;
}
pub inline fn Py_ABS(x: anytype) @TypeOf(if (__helpers.cast(bool, x < @as(c_int, 0))) -x else x) {
    _ = &x;
    return if (__helpers.cast(bool, x < @as(c_int, 0))) -x else x;
}
pub const _Py_XSTRINGIFY = @compileError("unable to translate C expr: unexpected token ''"); // /usr/include/python3.14/pymacro.h:76:9
pub inline fn Py_STRINGIFY(x: anytype) @TypeOf(_Py_XSTRINGIFY(x)) {
    _ = &x;
    return _Py_XSTRINGIFY(x);
}
pub const Py_MEMBER_SIZE = @compileError("unable to translate C expr: expected ')' instead got 'a number'"); // /usr/include/python3.14/pymacro.h:85:9
pub inline fn Py_CHARMASK(c: anytype) u8 {
    _ = &c;
    return __helpers.cast(u8, c & @as(c_int, 0xff));
}
pub const Py_BUILD_ASSERT_EXPR = @compileError("unable to translate macro: undefined identifier `dummy`"); // /usr/include/python3.14/pymacro.h:92:11
pub const Py_BUILD_ASSERT = @compileError("unable to translate C expr: unexpected token 'do'"); // /usr/include/python3.14/pymacro.h:116:11
pub const Py_ARRAY_LENGTH = @compileError("unable to translate macro: undefined identifier `__builtin_types_compatible_p`"); // /usr/include/python3.14/pymacro.h:140:9
pub const PyDoc_VAR = @compileError("unable to translate C expr: unexpected token 'static'"); // /usr/include/python3.14/pymacro.h:151:9
pub const PyDoc_STRVAR = @compileError("unable to translate C expr: unexpected token '='"); // /usr/include/python3.14/pymacro.h:152:9
pub inline fn PyDoc_STR(str: anytype) @TypeOf(str) {
    _ = &str;
    return str;
}
pub inline fn _Py_SIZE_ROUND_DOWN(n: anytype, a: anytype) @TypeOf(__helpers.cast(usize, n) & ~__helpers.cast(usize, a - @as(c_int, 1))) {
    _ = &n;
    _ = &a;
    return __helpers.cast(usize, n) & ~__helpers.cast(usize, a - @as(c_int, 1));
}
pub inline fn _Py_SIZE_ROUND_UP(n: anytype, a: anytype) @TypeOf((__helpers.cast(usize, n) + __helpers.cast(usize, a - @as(c_int, 1))) & ~__helpers.cast(usize, a - @as(c_int, 1))) {
    _ = &n;
    _ = &a;
    return (__helpers.cast(usize, n) + __helpers.cast(usize, a - @as(c_int, 1))) & ~__helpers.cast(usize, a - @as(c_int, 1));
}
pub inline fn _Py_ALIGN_DOWN(p: anytype, a: anytype) ?*anyopaque {
    _ = &p;
    _ = &a;
    return __helpers.cast(?*anyopaque, __helpers.cast(usize, p) & ~__helpers.cast(usize, a - @as(c_int, 1)));
}
pub inline fn _Py_ALIGN_UP(p: anytype, a: anytype) ?*anyopaque {
    _ = &p;
    _ = &a;
    return __helpers.cast(?*anyopaque, (__helpers.cast(usize, p) + __helpers.cast(usize, a - @as(c_int, 1))) & ~__helpers.cast(usize, a - @as(c_int, 1)));
}
pub inline fn _Py_IS_ALIGNED(p: anytype, a: anytype) @TypeOf(!((__helpers.cast(usize, p) & __helpers.cast(usize, a - @as(c_int, 1))) != 0)) {
    _ = &p;
    _ = &a;
    return !((__helpers.cast(usize, p) & __helpers.cast(usize, a - @as(c_int, 1))) != 0);
}
pub const Py_UNUSED = @compileError("unable to translate macro: undefined identifier `_unused_`"); // /usr/include/python3.14/pymacro.h:179:11
pub inline fn Py_UNREACHABLE() @TypeOf(__builtin.@"unreachable"()) {
    return __builtin.@"unreachable"();
}
pub inline fn _Py_CONTAINER_OF(ptr: anytype, @"type": anytype, member: anytype) @TypeOf([*c]@"type"(__helpers.cast([*c]u8, ptr) - offsetof(@"type", member))) {
    _ = &ptr;
    _ = &@"type";
    _ = &member;
    return [*c]@"type"(__helpers.cast([*c]u8, ptr) - offsetof(@"type", member));
}
pub inline fn _Py_RVALUE(EXPR: anytype) @TypeOf(EXPR) {
    _ = &EXPR;
    return blk_1: {
        _ = __helpers.cast(anyopaque, @as(c_int, 0));
        break :blk_1 EXPR;
    };
}
pub inline fn _Py_IS_TYPE_SIGNED(@"type": anytype) @TypeOf(@"type"(-@as(c_int, 1)) <= @as(c_int, 0)) {
    _ = &@"type";
    return @"type"(-@as(c_int, 1)) <= @as(c_int, 0);
}
pub const Py_PYMATH_H = "";
pub const Py_MATH_PIl = @as(c_longdouble, 3.1415926535897932384626433832795029);
pub const Py_MATH_PI = @as(f64, 3.14159265358979323846);
pub const Py_MATH_El = @as(c_longdouble, 2.7182818284590452353602874713526625);
pub const Py_MATH_E = @as(f64, 2.7182818284590452354);
pub const Py_MATH_TAU = @as(c_longdouble, 6.2831853071795864769252867665590057683943);
pub inline fn Py_IS_NAN(X: anytype) @TypeOf(isnan(X)) {
    _ = &X;
    return isnan(X);
}
pub inline fn Py_IS_INFINITY(X: anytype) @TypeOf(isinf(X)) {
    _ = &X;
    return isinf(X);
}
pub inline fn Py_IS_FINITE(X: anytype) @TypeOf(isfinite(X)) {
    _ = &X;
    return isfinite(X);
}
pub const Py_INFINITY = __helpers.cast(f64, INFINITY);
pub const Py_HUGE_VAL = HUGE_VAL;
pub const Py_NAN = __helpers.cast(f64, NAN);
pub const Py_PYMEM_H = "";
pub inline fn PyMem_New(@"type": anytype, n: anytype) @TypeOf(if (__helpers.cast(bool, __helpers.cast(usize, n) > __helpers.div(PY_SSIZE_T_MAX, __helpers.sizeof(@"type")))) NULL else [*c]@"type" ++ PyMem_Malloc(n * __helpers.sizeof(@"type"))) {
    _ = &@"type";
    _ = &n;
    return if (__helpers.cast(bool, __helpers.cast(usize, n) > __helpers.div(PY_SSIZE_T_MAX, __helpers.sizeof(@"type")))) NULL else [*c]@"type" ++ PyMem_Malloc(n * __helpers.sizeof(@"type"));
}
pub const PyMem_Resize = @compileError("unable to translate C expr: expected ')' instead got '='"); // /usr/include/python3.14/pymem.h:73:9
pub inline fn PyMem_MALLOC(n: anytype) @TypeOf(PyMem_Malloc(n)) {
    _ = &n;
    return PyMem_Malloc(n);
}
pub inline fn PyMem_NEW(@"type": anytype, n: anytype) @TypeOf(PyMem_New(@"type", n)) {
    _ = &@"type";
    _ = &n;
    return PyMem_New(@"type", n);
}
pub inline fn PyMem_REALLOC(p: anytype, n: anytype) @TypeOf(PyMem_Realloc(p, n)) {
    _ = &p;
    _ = &n;
    return PyMem_Realloc(p, n);
}
pub inline fn PyMem_RESIZE(p: anytype, @"type": anytype, n: anytype) @TypeOf(PyMem_Resize(p, @"type", n)) {
    _ = &p;
    _ = &@"type";
    _ = &n;
    return PyMem_Resize(p, @"type", n);
}
pub inline fn PyMem_FREE(p: anytype) @TypeOf(PyMem_Free(p)) {
    _ = &p;
    return PyMem_Free(p);
}
pub inline fn PyMem_Del(p: anytype) @TypeOf(PyMem_Free(p)) {
    _ = &p;
    return PyMem_Free(p);
}
pub inline fn PyMem_DEL(p: anytype) @TypeOf(PyMem_Free(p)) {
    _ = &p;
    return PyMem_Free(p);
}
pub const Py_PYTYPEDEFS_H = "";
pub const Py_BUFFER_H = "";
pub const PyBUF_MAX_NDIM = @as(c_int, 64);
pub const PyBUF_SIMPLE = @as(c_int, 0);
pub const PyBUF_WRITABLE = @as(c_int, 0x0001);
pub const PyBUF_WRITEABLE = PyBUF_WRITABLE;
pub const PyBUF_FORMAT = @as(c_int, 0x0004);
pub const PyBUF_ND = @as(c_int, 0x0008);
pub const PyBUF_STRIDES = @as(c_int, 0x0010) | PyBUF_ND;
pub const PyBUF_C_CONTIGUOUS = @as(c_int, 0x0020) | PyBUF_STRIDES;
pub const PyBUF_F_CONTIGUOUS = @as(c_int, 0x0040) | PyBUF_STRIDES;
pub const PyBUF_ANY_CONTIGUOUS = @as(c_int, 0x0080) | PyBUF_STRIDES;
pub const PyBUF_INDIRECT = @as(c_int, 0x0100) | PyBUF_STRIDES;
pub const PyBUF_CONTIG = PyBUF_ND | PyBUF_WRITABLE;
pub const PyBUF_CONTIG_RO = PyBUF_ND;
pub const PyBUF_STRIDED = PyBUF_STRIDES | PyBUF_WRITABLE;
pub const PyBUF_STRIDED_RO = PyBUF_STRIDES;
pub const PyBUF_RECORDS = (PyBUF_STRIDES | PyBUF_WRITABLE) | PyBUF_FORMAT;
pub const PyBUF_RECORDS_RO = PyBUF_STRIDES | PyBUF_FORMAT;
pub const PyBUF_FULL = (PyBUF_INDIRECT | PyBUF_WRITABLE) | PyBUF_FORMAT;
pub const PyBUF_FULL_RO = PyBUF_INDIRECT | PyBUF_FORMAT;
pub const PyBUF_READ = @as(c_int, 0x100);
pub const PyBUF_WRITE = @as(c_int, 0x200);
pub const Py_PYSTATS_H = "";
pub inline fn _Py_INCREF_STAT_INC() anyopaque {
    return __helpers.cast(anyopaque, @as(c_int, 0));
}
pub inline fn _Py_DECREF_STAT_INC() anyopaque {
    return __helpers.cast(anyopaque, @as(c_int, 0));
}
pub inline fn _Py_INCREF_IMMORTAL_STAT_INC() anyopaque {
    return __helpers.cast(anyopaque, @as(c_int, 0));
}
pub inline fn _Py_DECREF_IMMORTAL_STAT_INC() anyopaque {
    return __helpers.cast(anyopaque, @as(c_int, 0));
}
pub const Py_ATOMIC_H = "";
pub const _Py_USE_GCC_BUILTIN_ATOMICS = @as(c_int, 1);
pub inline fn _Py_atomic_load_ulong(p: anytype) @TypeOf(_Py_atomic_load_uint64(__helpers.cast([*c]u64, p))) {
    _ = &p;
    return _Py_atomic_load_uint64(__helpers.cast([*c]u64, p));
}
pub inline fn _Py_atomic_load_ulong_relaxed(p: anytype) @TypeOf(_Py_atomic_load_uint64_relaxed(__helpers.cast([*c]u64, p))) {
    _ = &p;
    return _Py_atomic_load_uint64_relaxed(__helpers.cast([*c]u64, p));
}
pub inline fn _Py_atomic_store_ulong(p: anytype, v: anytype) @TypeOf(_Py_atomic_store_uint64(__helpers.cast([*c]u64, p), v)) {
    _ = &p;
    _ = &v;
    return _Py_atomic_store_uint64(__helpers.cast([*c]u64, p), v);
}
pub inline fn _Py_atomic_store_ulong_relaxed(p: anytype, v: anytype) @TypeOf(_Py_atomic_store_uint64_relaxed(__helpers.cast([*c]u64, p), v)) {
    _ = &p;
    _ = &v;
    return _Py_atomic_store_uint64_relaxed(__helpers.cast([*c]u64, p), v);
}
pub const Py_LOCK_H = "";
pub const _Py_UNLOCKED = @as(c_int, 0);
pub const _Py_LOCKED = @as(c_int, 1);
pub const Py_CRITICAL_SECTION_H = "";
pub const Py_BEGIN_CRITICAL_SECTION = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/cpython/critical_section.h:92:10
pub const Py_BEGIN_CRITICAL_SECTION_MUTEX = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/cpython/critical_section.h:94:10
pub const Py_END_CRITICAL_SECTION = @compileError("unable to translate C expr: unexpected token '}'"); // /usr/include/python3.14/cpython/critical_section.h:96:10
pub const Py_BEGIN_CRITICAL_SECTION2 = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/cpython/critical_section.h:98:10
pub const Py_BEGIN_CRITICAL_SECTION2_MUTEX = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/cpython/critical_section.h:100:10
pub const Py_END_CRITICAL_SECTION2 = @compileError("unable to translate C expr: unexpected token '}'"); // /usr/include/python3.14/cpython/critical_section.h:102:10
pub const Py_OBJECT_H = "";
pub const PyObject_HEAD = @compileError("unable to translate macro: undefined identifier `ob_base`"); // /usr/include/python3.14/object.h:60:9
pub const _PyObject_EXTRA_INIT = "";
pub const PyObject_HEAD_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/object.h:82:9
pub const PyVarObject_HEAD_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/object.h:89:9
pub const PyObject_VAR_HEAD = @compileError("unable to translate macro: undefined identifier `ob_base`"); // /usr/include/python3.14/object.h:101:9
pub const Py_INVALID_SIZE = __helpers.cast(Py_ssize_t, -@as(c_int, 1));
pub inline fn _PyObject_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyObject, op)) {
    _ = &op;
    return _Py_CAST([*c]PyObject, op);
}
pub inline fn _PyVarObject_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyVarObject, op)) {
    _ = &op;
    return _Py_CAST([*c]PyVarObject, op);
}
pub const Py_TP_USE_SPEC = NULL;
pub const Py_PRINT_RAW = @as(c_int, 1);
pub const _Py_TPFLAGS_STATIC_BUILTIN = @as(c_int, 1) << @as(c_int, 1);
pub const Py_TPFLAGS_INLINE_VALUES = @as(c_int, 1) << @as(c_int, 2);
pub const Py_TPFLAGS_MANAGED_WEAKREF = @as(c_int, 1) << @as(c_int, 3);
pub const Py_TPFLAGS_MANAGED_DICT = @as(c_int, 1) << @as(c_int, 4);
pub const Py_TPFLAGS_PREHEADER = Py_TPFLAGS_MANAGED_WEAKREF | Py_TPFLAGS_MANAGED_DICT;
pub const Py_TPFLAGS_SEQUENCE = @as(c_int, 1) << @as(c_int, 5);
pub const Py_TPFLAGS_MAPPING = @as(c_int, 1) << @as(c_int, 6);
pub const Py_TPFLAGS_DISALLOW_INSTANTIATION = @as(c_ulong, 1) << @as(c_int, 7);
pub const Py_TPFLAGS_IMMUTABLETYPE = @as(c_ulong, 1) << @as(c_int, 8);
pub const Py_TPFLAGS_HEAPTYPE = @as(c_ulong, 1) << @as(c_int, 9);
pub const Py_TPFLAGS_BASETYPE = @as(c_ulong, 1) << @as(c_int, 10);
pub const Py_TPFLAGS_HAVE_VECTORCALL = @as(c_ulong, 1) << @as(c_int, 11);
pub const _Py_TPFLAGS_HAVE_VECTORCALL = Py_TPFLAGS_HAVE_VECTORCALL;
pub const Py_TPFLAGS_READY = @as(c_ulong, 1) << @as(c_int, 12);
pub const Py_TPFLAGS_READYING = @as(c_ulong, 1) << @as(c_int, 13);
pub const Py_TPFLAGS_HAVE_GC = @as(c_ulong, 1) << @as(c_int, 14);
pub const Py_TPFLAGS_HAVE_STACKLESS_EXTENSION = @as(c_int, 0);
pub const Py_TPFLAGS_METHOD_DESCRIPTOR = @as(c_ulong, 1) << @as(c_int, 17);
pub const Py_TPFLAGS_VALID_VERSION_TAG = @as(c_ulong, 1) << @as(c_int, 19);
pub const Py_TPFLAGS_IS_ABSTRACT = @as(c_ulong, 1) << @as(c_int, 20);
pub const _Py_TPFLAGS_MATCH_SELF = @as(c_ulong, 1) << @as(c_int, 22);
pub const Py_TPFLAGS_ITEMS_AT_END = @as(c_ulong, 1) << @as(c_int, 23);
pub const Py_TPFLAGS_LONG_SUBCLASS = @as(c_ulong, 1) << @as(c_int, 24);
pub const Py_TPFLAGS_LIST_SUBCLASS = @as(c_ulong, 1) << @as(c_int, 25);
pub const Py_TPFLAGS_TUPLE_SUBCLASS = @as(c_ulong, 1) << @as(c_int, 26);
pub const Py_TPFLAGS_BYTES_SUBCLASS = @as(c_ulong, 1) << @as(c_int, 27);
pub const Py_TPFLAGS_UNICODE_SUBCLASS = @as(c_ulong, 1) << @as(c_int, 28);
pub const Py_TPFLAGS_DICT_SUBCLASS = @as(c_ulong, 1) << @as(c_int, 29);
pub const Py_TPFLAGS_BASE_EXC_SUBCLASS = @as(c_ulong, 1) << @as(c_int, 30);
pub const Py_TPFLAGS_TYPE_SUBCLASS = @as(c_ulong, 1) << @as(c_int, 31);
pub const Py_TPFLAGS_DEFAULT = Py_TPFLAGS_HAVE_STACKLESS_EXTENSION | @as(c_int, 0);
pub const Py_TPFLAGS_HAVE_FINALIZE = @as(c_ulong, 1) << @as(c_int, 0);
pub const Py_TPFLAGS_HAVE_VERSION_TAG = @as(c_ulong, 1) << @as(c_int, 18);
pub const Py_CONSTANT_NONE = @as(c_int, 0);
pub const Py_CONSTANT_FALSE = @as(c_int, 1);
pub const Py_CONSTANT_TRUE = @as(c_int, 2);
pub const Py_CONSTANT_ELLIPSIS = @as(c_int, 3);
pub const Py_CONSTANT_NOT_IMPLEMENTED = @as(c_int, 4);
pub const Py_CONSTANT_ZERO = @as(c_int, 5);
pub const Py_CONSTANT_ONE = @as(c_int, 6);
pub const Py_CONSTANT_EMPTY_STR = @as(c_int, 7);
pub const Py_CONSTANT_EMPTY_BYTES = @as(c_int, 8);
pub const Py_CONSTANT_EMPTY_TUPLE = @as(c_int, 9);
// /usr/include/python3.14/object.h:650:11: warning: macro 'Py_None' contains a runtime value, translated to function
pub inline fn Py_None() @TypeOf(&_Py_NoneStruct) {
    return &_Py_NoneStruct;
}
pub const Py_RETURN_NONE = @compileError("unable to translate C expr: unexpected token 'return'"); // /usr/include/python3.14/object.h:662:11

// /usr/include/python3.14/object.h:674:11: warning: macro 'Py_NotImplemented' contains a runtime value, translated to function
pub inline fn Py_NotImplemented() @TypeOf(&_Py_NotImplementedStruct) {
    return &_Py_NotImplementedStruct;
}
pub const Py_RETURN_NOTIMPLEMENTED = @compileError("unable to translate C expr: unexpected token 'return'"); // /usr/include/python3.14/object.h:682:11
pub const Py_LT = @as(c_int, 0);
pub const Py_LE = @as(c_int, 1);
pub const Py_EQ = @as(c_int, 2);
pub const Py_NE = @as(c_int, 3);
pub const Py_GT = @as(c_int, 4);
pub const Py_GE = @as(c_int, 5);
pub const Py_RETURN_RICHCOMPARE = @compileError("unable to translate C expr: unexpected token 'do'"); // /usr/include/python3.14/object.h:707:9
pub const _Py_static_string_init = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/cpython/object.h:54:9
pub const _Py_static_string = @compileError("unable to translate C expr: unexpected token 'static'"); // /usr/include/python3.14/cpython/object.h:55:9
pub const _Py_IDENTIFIER = @compileError("unable to translate macro: undefined identifier `PyId_`"); // /usr/include/python3.14/cpython/object.h:56:9
pub const _Py_ATTR_CACHE_UNUSED = @as(c_int, 30000);
pub const Py_SETREF = @compileError("unable to translate macro: undefined identifier `_tmp_dst_ptr`"); // /usr/include/python3.14/cpython/object.h:342:9
pub const Py_XSETREF = @compileError("unable to translate macro: undefined identifier `_tmp_dst_ptr`"); // /usr/include/python3.14/cpython/object.h:364:9
pub inline fn _PyObject_ASSERT_FROM(obj: anytype, expr: anytype, msg: anytype, filename: anytype, lineno: anytype, func: anytype) anyopaque {
    _ = &obj;
    _ = &expr;
    _ = &msg;
    _ = &filename;
    _ = &lineno;
    _ = &func;
    return __helpers.cast(anyopaque, @as(c_int, 0));
}
pub const _PyObject_ASSERT_WITH_MSG = @compileError("unable to translate macro: undefined identifier `__FILE__`"); // /usr/include/python3.14/cpython/object.h:410:9
pub inline fn _PyObject_ASSERT(obj: anytype, expr: anytype) @TypeOf(_PyObject_ASSERT_WITH_MSG(obj, expr, NULL)) {
    _ = &obj;
    _ = &expr;
    return _PyObject_ASSERT_WITH_MSG(obj, expr, NULL);
}
pub const _PyObject_ASSERT_FAILED_MSG = @compileError("unable to translate macro: undefined identifier `__FILE__`"); // /usr/include/python3.14/cpython/object.h:415:9
pub inline fn Py_TRASHCAN_BEGIN(op: anytype, dealloc: anytype) void {
    _ = &op;
    _ = &dealloc;
    return;
}
pub const Py_TRASHCAN_END = "";
pub inline fn PyType_FastSubclass(@"type": anytype, flag: anytype) @TypeOf(PyType_HasFeature(@"type", flag)) {
    _ = &@"type";
    _ = &flag;
    return PyType_HasFeature(@"type", flag);
}
pub inline fn _PyType_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyTypeObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyType_Check(op));
        break :blk_1 _Py_CAST([*c]PyTypeObject, op);
    };
}
pub const _Py_REFCOUNT_H = "";
pub const _Py_STATICALLY_ALLOCATED_FLAG = @as(c_int, 4);
pub const _Py_IMMORTAL_FLAGS = @as(c_int, 1);
pub const _Py_IMMORTAL_INITIAL_REFCNT = @as(c_ulonglong, 3) << @as(c_int, 30);
pub const _Py_IMMORTAL_MINIMUM_REFCNT = @as(c_ulonglong, 1) << @as(c_int, 31);
pub const _Py_STATIC_FLAG_BITS = __helpers.cast(Py_ssize_t, _Py_STATICALLY_ALLOCATED_FLAG | _Py_IMMORTAL_FLAGS);
pub const _Py_STATIC_IMMORTAL_INITIAL_REFCNT = __helpers.cast(Py_ssize_t, _Py_IMMORTAL_INITIAL_REFCNT) | (_Py_STATIC_FLAG_BITS << @as(c_int, 48));
pub const Py_CLEAR = @compileError("unable to translate macro: undefined identifier `_tmp_op_ptr`"); // /usr/include/python3.14/refcount.h:477:9
pub const Py_OBJIMPL_H = "";
pub const PyObject_MALLOC = PyObject_Malloc;
pub const PyObject_REALLOC = PyObject_Realloc;
pub const PyObject_FREE = PyObject_Free;
pub const PyObject_Del = PyObject_Free;
pub const PyObject_DEL = PyObject_Free;
pub inline fn PyObject_INIT(op: anytype, typeobj: anytype) @TypeOf(PyObject_Init(_PyObject_CAST(op), typeobj)) {
    _ = &op;
    _ = &typeobj;
    return PyObject_Init(_PyObject_CAST(op), typeobj);
}
pub inline fn PyObject_INIT_VAR(op: anytype, typeobj: anytype, size: anytype) @TypeOf(PyObject_InitVar(_PyVarObject_CAST(op), typeobj, size)) {
    _ = &op;
    _ = &typeobj;
    _ = &size;
    return PyObject_InitVar(_PyVarObject_CAST(op), typeobj, size);
}
pub inline fn PyObject_New(@"type": anytype, typeobj: anytype) @TypeOf([*c]@"type" ++ _PyObject_New(typeobj)) {
    _ = &@"type";
    _ = &typeobj;
    return [*c]@"type" ++ _PyObject_New(typeobj);
}
pub inline fn PyObject_NEW(@"type": anytype, typeobj: anytype) @TypeOf(PyObject_New(@"type", typeobj)) {
    _ = &@"type";
    _ = &typeobj;
    return PyObject_New(@"type", typeobj);
}
pub inline fn PyObject_NewVar(@"type": anytype, typeobj: anytype, n: anytype) @TypeOf([*c]@"type" ++ _PyObject_NewVar(typeobj, n)) {
    _ = &@"type";
    _ = &typeobj;
    _ = &n;
    return [*c]@"type" ++ _PyObject_NewVar(typeobj, n);
}
pub inline fn PyObject_NEW_VAR(@"type": anytype, typeobj: anytype, n: anytype) @TypeOf(PyObject_NewVar(@"type", typeobj, n)) {
    _ = &@"type";
    _ = &typeobj;
    _ = &n;
    return PyObject_NewVar(@"type", typeobj, n);
}
pub inline fn PyType_IS_GC(t: anytype) @TypeOf(PyType_HasFeature(t, Py_TPFLAGS_HAVE_GC)) {
    _ = &t;
    return PyType_HasFeature(t, Py_TPFLAGS_HAVE_GC);
}
pub inline fn PyObject_GC_Resize(@"type": anytype, op: anytype, n: anytype) @TypeOf([*c]@"type" ++ _PyObject_GC_Resize(_PyVarObject_CAST(op), n)) {
    _ = &@"type";
    _ = &op;
    _ = &n;
    return [*c]@"type" ++ _PyObject_GC_Resize(_PyVarObject_CAST(op), n);
}
pub inline fn PyObject_GC_New(@"type": anytype, typeobj: anytype) @TypeOf(_Py_CAST([*c]@"type", _PyObject_GC_New(typeobj))) {
    _ = &@"type";
    _ = &typeobj;
    return _Py_CAST([*c]@"type", _PyObject_GC_New(typeobj));
}
pub inline fn PyObject_GC_NewVar(@"type": anytype, typeobj: anytype, n: anytype) @TypeOf(_Py_CAST([*c]@"type", _PyObject_GC_NewVar(typeobj, n))) {
    _ = &@"type";
    _ = &typeobj;
    _ = &n;
    return _Py_CAST([*c]@"type", _PyObject_GC_NewVar(typeobj, n));
}
pub const Py_VISIT = @compileError("unable to translate macro: undefined identifier `vret`"); // /usr/include/python3.14/objimpl.h:193:9
pub const Py_bf_getbuffer = @as(c_int, 1);
pub const Py_bf_releasebuffer = @as(c_int, 2);
pub const Py_mp_ass_subscript = @as(c_int, 3);
pub const Py_mp_length = @as(c_int, 4);
pub const Py_mp_subscript = @as(c_int, 5);
pub const Py_nb_absolute = @as(c_int, 6);
pub const Py_nb_add = @as(c_int, 7);
pub const Py_nb_and = @as(c_int, 8);
pub const Py_nb_bool = @as(c_int, 9);
pub const Py_nb_divmod = @as(c_int, 10);
pub const Py_nb_float = @as(c_int, 11);
pub const Py_nb_floor_divide = @as(c_int, 12);
pub const Py_nb_index = @as(c_int, 13);
pub const Py_nb_inplace_add = @as(c_int, 14);
pub const Py_nb_inplace_and = @as(c_int, 15);
pub const Py_nb_inplace_floor_divide = @as(c_int, 16);
pub const Py_nb_inplace_lshift = @as(c_int, 17);
pub const Py_nb_inplace_multiply = @as(c_int, 18);
pub const Py_nb_inplace_or = @as(c_int, 19);
pub const Py_nb_inplace_power = @as(c_int, 20);
pub const Py_nb_inplace_remainder = @as(c_int, 21);
pub const Py_nb_inplace_rshift = @as(c_int, 22);
pub const Py_nb_inplace_subtract = @as(c_int, 23);
pub const Py_nb_inplace_true_divide = @as(c_int, 24);
pub const Py_nb_inplace_xor = @as(c_int, 25);
pub const Py_nb_int = @as(c_int, 26);
pub const Py_nb_invert = @as(c_int, 27);
pub const Py_nb_lshift = @as(c_int, 28);
pub const Py_nb_multiply = @as(c_int, 29);
pub const Py_nb_negative = @as(c_int, 30);
pub const Py_nb_or = @as(c_int, 31);
pub const Py_nb_positive = @as(c_int, 32);
pub const Py_nb_power = @as(c_int, 33);
pub const Py_nb_remainder = @as(c_int, 34);
pub const Py_nb_rshift = @as(c_int, 35);
pub const Py_nb_subtract = @as(c_int, 36);
pub const Py_nb_true_divide = @as(c_int, 37);
pub const Py_nb_xor = @as(c_int, 38);
pub const Py_sq_ass_item = @as(c_int, 39);
pub const Py_sq_concat = @as(c_int, 40);
pub const Py_sq_contains = @as(c_int, 41);
pub const Py_sq_inplace_concat = @as(c_int, 42);
pub const Py_sq_inplace_repeat = @as(c_int, 43);
pub const Py_sq_item = @as(c_int, 44);
pub const Py_sq_length = @as(c_int, 45);
pub const Py_sq_repeat = @as(c_int, 46);
pub const Py_tp_alloc = @as(c_int, 47);
pub const Py_tp_base = @as(c_int, 48);
pub const Py_tp_bases = @as(c_int, 49);
pub const Py_tp_call = @as(c_int, 50);
pub const Py_tp_clear = @as(c_int, 51);
pub const Py_tp_dealloc = @as(c_int, 52);
pub const Py_tp_del = @as(c_int, 53);
pub const Py_tp_descr_get = @as(c_int, 54);
pub const Py_tp_descr_set = @as(c_int, 55);
pub const Py_tp_doc = @as(c_int, 56);
pub const Py_tp_getattr = @as(c_int, 57);
pub const Py_tp_getattro = @as(c_int, 58);
pub const Py_tp_hash = @as(c_int, 59);
pub const Py_tp_init = @as(c_int, 60);
pub const Py_tp_is_gc = @as(c_int, 61);
pub const Py_tp_iter = @as(c_int, 62);
pub const Py_tp_iternext = @as(c_int, 63);
pub const Py_tp_methods = @as(c_int, 64);
pub const Py_tp_new = @as(c_int, 65);
pub const Py_tp_repr = @as(c_int, 66);
pub const Py_tp_richcompare = @as(c_int, 67);
pub const Py_tp_setattr = @as(c_int, 68);
pub const Py_tp_setattro = @as(c_int, 69);
pub const Py_tp_str = @as(c_int, 70);
pub const Py_tp_traverse = @as(c_int, 71);
pub const Py_tp_members = @as(c_int, 72);
pub const Py_tp_getset = @as(c_int, 73);
pub const Py_tp_free = @as(c_int, 74);
pub const Py_nb_matrix_multiply = @as(c_int, 75);
pub const Py_nb_inplace_matrix_multiply = @as(c_int, 76);
pub const Py_am_await = @as(c_int, 77);
pub const Py_am_aiter = @as(c_int, 78);
pub const Py_am_anext = @as(c_int, 79);
pub const Py_tp_finalize = @as(c_int, 80);
pub const Py_am_send = @as(c_int, 81);
pub const Py_tp_vectorcall = @as(c_int, 82);
pub const Py_tp_token = @as(c_int, 83);
pub const Py_HASH_H = "";
pub const Py_HASH_CUTOFF = @as(c_int, 0);
pub const Py_HASH_EXTERNAL = @as(c_int, 0);
pub const Py_HASH_SIPHASH24 = @as(c_int, 1);
pub const Py_HASH_FNV = @as(c_int, 2);
pub const Py_HASH_SIPHASH13 = @as(c_int, 3);
pub const Py_HASH_ALGORITHM = Py_HASH_SIPHASH13;
pub const PyHASH_MULTIPLIER = @as(c_ulong, 1000003);
pub const PyHASH_BITS = @as(c_int, 61);
pub const PyHASH_MODULUS = (__helpers.cast(usize, @as(c_int, 1)) << _PyHASH_BITS) - @as(c_int, 1);
pub const PyHASH_INF = __helpers.promoteIntLiteral(c_int, 314159, .decimal);
pub const PyHASH_IMAG = PyHASH_MULTIPLIER;
pub const _PyHASH_MULTIPLIER = PyHASH_MULTIPLIER;
pub const _PyHASH_BITS = PyHASH_BITS;
pub const _PyHASH_MODULUS = PyHASH_MODULUS;
pub const _PyHASH_INF = PyHASH_INF;
pub const _PyHASH_IMAG = PyHASH_IMAG;
pub const Py_PYDEBUG_H = "";
pub const Py_BYTEARRAYOBJECT_H = "";
pub inline fn PyByteArray_Check(self: anytype) @TypeOf(PyObject_TypeCheck(self, &PyByteArray_Type)) {
    _ = &self;
    return PyObject_TypeCheck(self, &PyByteArray_Type);
}
pub inline fn PyByteArray_CheckExact(self: anytype) @TypeOf(Py_IS_TYPE(self, &PyByteArray_Type)) {
    _ = &self;
    return Py_IS_TYPE(self, &PyByteArray_Type);
}
pub inline fn _PyByteArray_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyByteArrayObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyByteArray_Check(op));
        break :blk_1 _Py_CAST([*c]PyByteArrayObject, op);
    };
}
pub const Py_BYTESOBJECT_H = "";
pub inline fn PyBytes_Check(op: anytype) @TypeOf(PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_BYTES_SUBCLASS)) {
    _ = &op;
    return PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_BYTES_SUBCLASS);
}
pub inline fn PyBytes_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyBytes_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyBytes_Type);
}
pub inline fn _PyBytes_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyBytesObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyBytes_Check(op));
        break :blk_1 _Py_CAST([*c]PyBytesObject, op);
    };
}
pub const Py_UNICODEOBJECT_H = "";
pub const Py_USING_UNICODE = "";
pub const Py_UNICODE_SIZE = SIZEOF_WCHAR_T;
pub const Py_UNICODE_WIDE = "";
pub inline fn PyUnicode_Check(op: anytype) @TypeOf(PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_UNICODE_SUBCLASS)) {
    _ = &op;
    return PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}
pub inline fn PyUnicode_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyUnicode_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyUnicode_Type);
}
pub const Py_UNICODE_REPLACEMENT_CHARACTER = __helpers.cast(Py_UCS4, __helpers.promoteIntLiteral(c_int, 0xFFFD, .hex));
pub inline fn _PyASCIIObject_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyASCIIObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyUnicode_Check(op));
        break :blk_1 _Py_CAST([*c]PyASCIIObject, op);
    };
}
pub inline fn _PyCompactUnicodeObject_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyCompactUnicodeObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyUnicode_Check(op));
        break :blk_1 _Py_CAST([*c]PyCompactUnicodeObject, op);
    };
}
pub inline fn _PyUnicodeObject_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyUnicodeObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyUnicode_Check(op));
        break :blk_1 _Py_CAST([*c]PyUnicodeObject, op);
    };
}
pub const SSTATE_NOT_INTERNED = @as(c_int, 0);
pub const SSTATE_INTERNED_MORTAL = @as(c_int, 1);
pub const SSTATE_INTERNED_IMMORTAL = @as(c_int, 2);
pub const SSTATE_INTERNED_IMMORTAL_STATIC = @as(c_int, 3);
pub inline fn PyUnicode_1BYTE_DATA(op: anytype) @TypeOf(_Py_STATIC_CAST([*c]Py_UCS1, PyUnicode_DATA(op))) {
    _ = &op;
    return _Py_STATIC_CAST([*c]Py_UCS1, PyUnicode_DATA(op));
}
pub inline fn PyUnicode_2BYTE_DATA(op: anytype) @TypeOf(_Py_STATIC_CAST([*c]Py_UCS2, PyUnicode_DATA(op))) {
    _ = &op;
    return _Py_STATIC_CAST([*c]Py_UCS2, PyUnicode_DATA(op));
}
pub inline fn PyUnicode_4BYTE_DATA(op: anytype) @TypeOf(_Py_STATIC_CAST([*c]Py_UCS4, PyUnicode_DATA(op))) {
    _ = &op;
    return _Py_STATIC_CAST([*c]Py_UCS4, PyUnicode_DATA(op));
}
pub inline fn _PyUnicodeWriter_Prepare(WRITER: anytype, LENGTH: anytype, MAXCHAR: anytype) @TypeOf(if (__helpers.cast(bool, (MAXCHAR <= WRITER.*.maxchar) and (LENGTH <= (WRITER.*.size - WRITER.*.pos)))) @as(c_int, 0) else if (__helpers.cast(bool, LENGTH == @as(c_int, 0))) @as(c_int, 0) else _PyUnicodeWriter_PrepareInternal(WRITER, LENGTH, MAXCHAR)) {
    _ = &WRITER;
    _ = &LENGTH;
    _ = &MAXCHAR;
    return if (__helpers.cast(bool, (MAXCHAR <= WRITER.*.maxchar) and (LENGTH <= (WRITER.*.size - WRITER.*.pos)))) @as(c_int, 0) else if (__helpers.cast(bool, LENGTH == @as(c_int, 0))) @as(c_int, 0) else _PyUnicodeWriter_PrepareInternal(WRITER, LENGTH, MAXCHAR);
}
pub inline fn _PyUnicodeWriter_PrepareKind(WRITER: anytype, KIND: anytype) @TypeOf(if (__helpers.cast(bool, KIND <= WRITER.*.kind)) @as(c_int, 0) else _PyUnicodeWriter_PrepareKindInternal(WRITER, KIND)) {
    _ = &WRITER;
    _ = &KIND;
    return if (__helpers.cast(bool, KIND <= WRITER.*.kind)) @as(c_int, 0) else _PyUnicodeWriter_PrepareKindInternal(WRITER, KIND);
}
pub inline fn Py_UNICODE_ISLOWER(ch: anytype) @TypeOf(_PyUnicode_IsLowercase(ch)) {
    _ = &ch;
    return _PyUnicode_IsLowercase(ch);
}
pub inline fn Py_UNICODE_ISUPPER(ch: anytype) @TypeOf(_PyUnicode_IsUppercase(ch)) {
    _ = &ch;
    return _PyUnicode_IsUppercase(ch);
}
pub inline fn Py_UNICODE_ISTITLE(ch: anytype) @TypeOf(_PyUnicode_IsTitlecase(ch)) {
    _ = &ch;
    return _PyUnicode_IsTitlecase(ch);
}
pub inline fn Py_UNICODE_ISLINEBREAK(ch: anytype) @TypeOf(_PyUnicode_IsLinebreak(ch)) {
    _ = &ch;
    return _PyUnicode_IsLinebreak(ch);
}
pub inline fn Py_UNICODE_TOLOWER(ch: anytype) @TypeOf(_PyUnicode_ToLowercase(ch)) {
    _ = &ch;
    return _PyUnicode_ToLowercase(ch);
}
pub inline fn Py_UNICODE_TOUPPER(ch: anytype) @TypeOf(_PyUnicode_ToUppercase(ch)) {
    _ = &ch;
    return _PyUnicode_ToUppercase(ch);
}
pub inline fn Py_UNICODE_TOTITLE(ch: anytype) @TypeOf(_PyUnicode_ToTitlecase(ch)) {
    _ = &ch;
    return _PyUnicode_ToTitlecase(ch);
}
pub inline fn Py_UNICODE_ISDECIMAL(ch: anytype) @TypeOf(_PyUnicode_IsDecimalDigit(ch)) {
    _ = &ch;
    return _PyUnicode_IsDecimalDigit(ch);
}
pub inline fn Py_UNICODE_ISDIGIT(ch: anytype) @TypeOf(_PyUnicode_IsDigit(ch)) {
    _ = &ch;
    return _PyUnicode_IsDigit(ch);
}
pub inline fn Py_UNICODE_ISNUMERIC(ch: anytype) @TypeOf(_PyUnicode_IsNumeric(ch)) {
    _ = &ch;
    return _PyUnicode_IsNumeric(ch);
}
pub inline fn Py_UNICODE_ISPRINTABLE(ch: anytype) @TypeOf(_PyUnicode_IsPrintable(ch)) {
    _ = &ch;
    return _PyUnicode_IsPrintable(ch);
}
pub inline fn Py_UNICODE_TODECIMAL(ch: anytype) @TypeOf(_PyUnicode_ToDecimalDigit(ch)) {
    _ = &ch;
    return _PyUnicode_ToDecimalDigit(ch);
}
pub inline fn Py_UNICODE_TODIGIT(ch: anytype) @TypeOf(_PyUnicode_ToDigit(ch)) {
    _ = &ch;
    return _PyUnicode_ToDigit(ch);
}
pub inline fn Py_UNICODE_TONUMERIC(ch: anytype) @TypeOf(_PyUnicode_ToNumeric(ch)) {
    _ = &ch;
    return _PyUnicode_ToNumeric(ch);
}
pub inline fn Py_UNICODE_ISALPHA(ch: anytype) @TypeOf(_PyUnicode_IsAlpha(ch)) {
    _ = &ch;
    return _PyUnicode_IsAlpha(ch);
}
pub const Py_ERRORS_H = "";
pub inline fn PyExceptionClass_Check(x: anytype) @TypeOf((PyType_Check(x) != 0) and (PyType_FastSubclass(__helpers.cast([*c]PyTypeObject, x), Py_TPFLAGS_BASE_EXC_SUBCLASS) != 0)) {
    _ = &x;
    return (PyType_Check(x) != 0) and (PyType_FastSubclass(__helpers.cast([*c]PyTypeObject, x), Py_TPFLAGS_BASE_EXC_SUBCLASS) != 0);
}
pub inline fn PyExceptionInstance_Check(x: anytype) @TypeOf(PyType_FastSubclass(Py_TYPE(x), Py_TPFLAGS_BASE_EXC_SUBCLASS)) {
    _ = &x;
    return PyType_FastSubclass(Py_TYPE(x), Py_TPFLAGS_BASE_EXC_SUBCLASS);
}
pub inline fn PyExceptionInstance_Class(x: anytype) @TypeOf(_PyObject_CAST(Py_TYPE(x))) {
    _ = &x;
    return _PyObject_CAST(Py_TYPE(x));
}
pub inline fn _PyBaseExceptionGroup_Check(x: anytype) @TypeOf(PyObject_TypeCheck(x, __helpers.cast([*c]PyTypeObject, PyExc_BaseExceptionGroup))) {
    _ = &x;
    return PyObject_TypeCheck(x, __helpers.cast([*c]PyTypeObject, PyExc_BaseExceptionGroup));
}
pub const PyException_HEAD = @compileError("unable to translate macro: undefined identifier `dict`"); // /usr/include/python3.14/cpython/pyerrors.h:8:9
pub const Py_LONGOBJECT_H = "";
pub inline fn PyLong_Check(op: anytype) @TypeOf(PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_LONG_SUBCLASS)) {
    _ = &op;
    return PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_LONG_SUBCLASS);
}
pub inline fn PyLong_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyLong_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyLong_Type);
}
pub const Py_ASNATIVEBYTES_DEFAULTS = -@as(c_int, 1);
pub const Py_ASNATIVEBYTES_BIG_ENDIAN = @as(c_int, 0);
pub const Py_ASNATIVEBYTES_LITTLE_ENDIAN = @as(c_int, 1);
pub const Py_ASNATIVEBYTES_NATIVE_ENDIAN = @as(c_int, 3);
pub const Py_ASNATIVEBYTES_UNSIGNED_BUFFER = @as(c_int, 4);
pub const Py_ASNATIVEBYTES_REJECT_NEGATIVE = @as(c_int, 8);
pub const Py_ASNATIVEBYTES_ALLOW_INDEX = @as(c_int, 16);
pub inline fn PyLong_AS_LONG(op: anytype) @TypeOf(PyLong_AsLong(op)) {
    _ = &op;
    return PyLong_AsLong(op);
}
pub const _Py_PARSE_PID = "i";
pub const PyLong_FromPid = PyLong_FromLong;
pub const PyLong_AsPid = PyLong_AsInt;
pub const _Py_PARSE_INTPTR = "l";
pub const _Py_PARSE_UINTPTR = "k";
pub inline fn _PyLong_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyLongObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyLong_Check(op));
        break :blk_1 _Py_CAST([*c]PyLongObject, op);
    };
}
pub const Py_LONGINTREPR_H = "";
pub const PyLong_SHIFT = @as(c_int, 30);
pub const _PyLong_DECIMAL_SHIFT = @as(c_int, 9);
pub const _PyLong_DECIMAL_BASE = __helpers.cast(digit, __helpers.promoteIntLiteral(c_int, 1000000000, .decimal));
pub const PyLong_BASE = __helpers.cast(digit, @as(c_int, 1)) << PyLong_SHIFT;
pub const PyLong_MASK = __helpers.cast(digit, PyLong_BASE - @as(c_int, 1));
pub const _PyLong_SIGN_MASK = @as(c_int, 3);
pub const _PyLong_NON_SIZE_BITS = @as(c_int, 3);
pub const Py_BOOLOBJECT_H = "";
pub inline fn PyBool_Check(x: anytype) @TypeOf(Py_IS_TYPE(x, &PyBool_Type)) {
    _ = &x;
    return Py_IS_TYPE(x, &PyBool_Type);
}
// /usr/include/python3.14/boolobject.h:25:11: warning: macro 'Py_False' contains a runtime value, translated to function
pub inline fn Py_False() @TypeOf(_PyObject_CAST(&_Py_FalseStruct)) {
    return _PyObject_CAST(&_Py_FalseStruct);
}
// /usr/include/python3.14/boolobject.h:26:11: warning: macro 'Py_True' contains a runtime value, translated to function
pub inline fn Py_True() @TypeOf(_PyObject_CAST(&_Py_TrueStruct)) {
    return _PyObject_CAST(&_Py_TrueStruct);
}
pub const Py_RETURN_TRUE = @compileError("unable to translate C expr: unexpected token 'return'"); // /usr/include/python3.14/boolobject.h:44:11
pub const Py_RETURN_FALSE = @compileError("unable to translate C expr: unexpected token 'return'"); // /usr/include/python3.14/boolobject.h:45:11
pub const Py_FLOATOBJECT_H = "";
pub inline fn PyFloat_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyFloat_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyFloat_Type);
}
pub inline fn PyFloat_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyFloat_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyFloat_Type);
}
pub const Py_RETURN_NAN = @compileError("unable to translate C expr: unexpected token 'return'"); // /usr/include/python3.14/floatobject.h:19:9
pub const Py_RETURN_INF = @compileError("unable to translate C expr: unexpected token 'do'"); // /usr/include/python3.14/floatobject.h:21:9
pub inline fn _PyFloat_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyFloatObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyFloat_Check(op));
        break :blk_1 _Py_CAST([*c]PyFloatObject, op);
    };
}
pub const Py_COMPLEXOBJECT_H = "";
pub inline fn PyComplex_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyComplex_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyComplex_Type);
}
pub inline fn PyComplex_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyComplex_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyComplex_Type);
}
pub const Py_RANGEOBJECT_H = "";
pub inline fn PyRange_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyRange_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyRange_Type);
}
pub const Py_MEMORYOBJECT_H = "";
pub inline fn PyMemoryView_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyMemoryView_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyMemoryView_Type);
}
pub const _Py_MANAGED_BUFFER_RELEASED = @as(c_int, 0x001);
pub const _Py_MANAGED_BUFFER_FREE_FORMAT = @as(c_int, 0x002);
pub const _Py_MEMORYVIEW_RELEASED = @as(c_int, 0x001);
pub const _Py_MEMORYVIEW_C = @as(c_int, 0x002);
pub const _Py_MEMORYVIEW_FORTRAN = @as(c_int, 0x004);
pub const _Py_MEMORYVIEW_SCALAR = @as(c_int, 0x008);
pub const _Py_MEMORYVIEW_PIL = @as(c_int, 0x010);
pub const _Py_MEMORYVIEW_RESTRICTED = @as(c_int, 0x020);
pub inline fn _PyMemoryView_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyMemoryViewObject, op)) {
    _ = &op;
    return _Py_CAST([*c]PyMemoryViewObject, op);
}
pub const Py_TUPLEOBJECT_H = "";
pub inline fn PyTuple_Check(op: anytype) @TypeOf(PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_TUPLE_SUBCLASS)) {
    _ = &op;
    return PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}
pub inline fn PyTuple_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyTuple_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyTuple_Type);
}
pub inline fn _PyTuple_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyTupleObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyTuple_Check(op));
        break :blk_1 _Py_CAST([*c]PyTupleObject, op);
    };
}
pub inline fn PyTuple_GET_ITEM(op: anytype, index_1: anytype) @TypeOf(_PyTuple_CAST(op).*.ob_item[@as(usize, @intCast(index_1))]) {
    _ = &op;
    _ = &index_1;
    return _PyTuple_CAST(op).*.ob_item[@as(usize, @intCast(index_1))];
}
pub const Py_LISTOBJECT_H = "";
pub inline fn PyList_Check(op: anytype) @TypeOf(PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_LIST_SUBCLASS)) {
    _ = &op;
    return PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_LIST_SUBCLASS);
}
pub inline fn PyList_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyList_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyList_Type);
}
pub inline fn _PyList_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyListObject, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyList_Check(op));
        break :blk_1 _Py_CAST([*c]PyListObject, op);
    };
}
pub inline fn PyList_GET_ITEM(op: anytype, index_1: anytype) @TypeOf(_PyList_CAST(op).*.ob_item[@as(usize, @intCast(index_1))]) {
    _ = &op;
    _ = &index_1;
    return _PyList_CAST(op).*.ob_item[@as(usize, @intCast(index_1))];
}
pub const Py_DICTOBJECT_H = "";
pub inline fn PyDict_Check(op: anytype) @TypeOf(PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_DICT_SUBCLASS)) {
    _ = &op;
    return PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_DICT_SUBCLASS);
}
pub inline fn PyDict_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyDict_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyDict_Type);
}
pub inline fn PyDictKeys_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyDictKeys_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyDictKeys_Type);
}
pub inline fn PyDictValues_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyDictValues_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyDictValues_Type);
}
pub inline fn PyDictItems_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyDictItems_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyDictItems_Type);
}
pub inline fn PyDictViewSet_Check(op: anytype) @TypeOf((PyDictKeys_Check(op) != 0) or (PyDictItems_Check(op) != 0)) {
    _ = &op;
    return (PyDictKeys_Check(op) != 0) or (PyDictItems_Check(op) != 0);
}
pub const PY_FOREACH_DICT_EVENT = @compileError("unable to translate macro: undefined identifier `ADDED`"); // /usr/include/python3.14/cpython/dictobject.h:80:9
pub const Py_ODICTOBJECT_H = "";
pub inline fn PyODict_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyODict_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyODict_Type);
}
pub inline fn PyODict_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyODict_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyODict_Type);
}
pub inline fn PyODict_SIZE(op: anytype) @TypeOf(PyDict_GET_SIZE(op)) {
    _ = &op;
    return PyDict_GET_SIZE(op);
}
pub inline fn PyODict_GetItem(od: anytype, key: anytype) @TypeOf(PyDict_GetItem(_PyObject_CAST(od), key)) {
    _ = &od;
    _ = &key;
    return PyDict_GetItem(_PyObject_CAST(od), key);
}
pub inline fn PyODict_GetItemWithError(od: anytype, key: anytype) @TypeOf(PyDict_GetItemWithError(_PyObject_CAST(od), key)) {
    _ = &od;
    _ = &key;
    return PyDict_GetItemWithError(_PyObject_CAST(od), key);
}
pub inline fn PyODict_Contains(od: anytype, key: anytype) @TypeOf(PyDict_Contains(_PyObject_CAST(od), key)) {
    _ = &od;
    _ = &key;
    return PyDict_Contains(_PyObject_CAST(od), key);
}
pub inline fn PyODict_Size(od: anytype) @TypeOf(PyDict_Size(_PyObject_CAST(od))) {
    _ = &od;
    return PyDict_Size(_PyObject_CAST(od));
}
pub inline fn PyODict_GetItemString(od: anytype, key: anytype) @TypeOf(PyDict_GetItemString(_PyObject_CAST(od), key)) {
    _ = &od;
    _ = &key;
    return PyDict_GetItemString(_PyObject_CAST(od), key);
}
pub const Py_ENUMOBJECT_H = "";
pub const Py_SETOBJECT_H = "";
pub inline fn PyFrozenSet_CheckExact(ob: anytype) @TypeOf(Py_IS_TYPE(ob, &PyFrozenSet_Type)) {
    _ = &ob;
    return Py_IS_TYPE(ob, &PyFrozenSet_Type);
}
pub inline fn PyFrozenSet_Check(ob: anytype) @TypeOf((Py_IS_TYPE(ob, &PyFrozenSet_Type) != 0) or (PyType_IsSubtype(Py_TYPE(ob), &PyFrozenSet_Type) != 0)) {
    _ = &ob;
    return (Py_IS_TYPE(ob, &PyFrozenSet_Type) != 0) or (PyType_IsSubtype(Py_TYPE(ob), &PyFrozenSet_Type) != 0);
}
pub inline fn PyAnySet_CheckExact(ob: anytype) @TypeOf((Py_IS_TYPE(ob, &PySet_Type) != 0) or (Py_IS_TYPE(ob, &PyFrozenSet_Type) != 0)) {
    _ = &ob;
    return (Py_IS_TYPE(ob, &PySet_Type) != 0) or (Py_IS_TYPE(ob, &PyFrozenSet_Type) != 0);
}
pub inline fn PyAnySet_Check(ob: anytype) @TypeOf((((Py_IS_TYPE(ob, &PySet_Type) != 0) or (Py_IS_TYPE(ob, &PyFrozenSet_Type) != 0)) or (PyType_IsSubtype(Py_TYPE(ob), &PySet_Type) != 0)) or (PyType_IsSubtype(Py_TYPE(ob), &PyFrozenSet_Type) != 0)) {
    _ = &ob;
    return (((Py_IS_TYPE(ob, &PySet_Type) != 0) or (Py_IS_TYPE(ob, &PyFrozenSet_Type) != 0)) or (PyType_IsSubtype(Py_TYPE(ob), &PySet_Type) != 0)) or (PyType_IsSubtype(Py_TYPE(ob), &PyFrozenSet_Type) != 0);
}
pub inline fn PySet_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PySet_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PySet_Type);
}
pub inline fn PySet_Check(ob: anytype) @TypeOf((Py_IS_TYPE(ob, &PySet_Type) != 0) or (PyType_IsSubtype(Py_TYPE(ob), &PySet_Type) != 0)) {
    _ = &ob;
    return (Py_IS_TYPE(ob, &PySet_Type) != 0) or (PyType_IsSubtype(Py_TYPE(ob), &PySet_Type) != 0);
}
pub const PySet_MINSIZE = @as(c_int, 8);
pub inline fn _PySet_CAST(so: anytype) @TypeOf(_Py_CAST([*c]PySetObject, so)) {
    _ = &so;
    return blk_1: {
        _ = assert(PyAnySet_Check(so));
        break :blk_1 _Py_CAST([*c]PySetObject, so);
    };
}
pub const Py_METHODOBJECT_H = "";
pub inline fn PyCFunction_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyCFunction_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyCFunction_Type);
}
pub inline fn PyCFunction_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyCFunction_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyCFunction_Type);
}
pub inline fn _PyCFunction_CAST(func: anytype) @TypeOf(_Py_FUNC_CAST(PyCFunction, func)) {
    _ = &func;
    return _Py_FUNC_CAST(PyCFunction, func);
}
pub inline fn _PyCFunctionFast_CAST(func: anytype) @TypeOf(_Py_FUNC_CAST(PyCFunctionFast, func)) {
    _ = &func;
    return _Py_FUNC_CAST(PyCFunctionFast, func);
}
pub inline fn _PyCFunctionWithKeywords_CAST(func: anytype) @TypeOf(_Py_FUNC_CAST(PyCFunctionWithKeywords, func)) {
    _ = &func;
    return _Py_FUNC_CAST(PyCFunctionWithKeywords, func);
}
pub inline fn _PyCFunctionFastWithKeywords_CAST(func: anytype) @TypeOf(_Py_FUNC_CAST(PyCFunctionFastWithKeywords, func)) {
    _ = &func;
    return _Py_FUNC_CAST(PyCFunctionFastWithKeywords, func);
}
pub const METH_VARARGS = @as(c_int, 0x0001);
pub const METH_KEYWORDS = @as(c_int, 0x0002);
pub const METH_NOARGS = @as(c_int, 0x0004);
pub const METH_O = @as(c_int, 0x0008);
pub const METH_CLASS = @as(c_int, 0x0010);
pub const METH_STATIC = @as(c_int, 0x0020);
pub const METH_COEXIST = @as(c_int, 0x0040);
pub const METH_FASTCALL = @as(c_int, 0x0080);
pub const METH_STACKLESS = @as(c_int, 0x0000);
pub const METH_METHOD = @as(c_int, 0x0200);
pub inline fn _PyCFunctionObject_CAST(func: anytype) @TypeOf(_Py_CAST([*c]PyCFunctionObject, func)) {
    _ = &func;
    return blk_1: {
        _ = assert(PyCFunction_Check(func));
        break :blk_1 _Py_CAST([*c]PyCFunctionObject, func);
    };
}
pub inline fn _PyCMethodObject_CAST(func: anytype) @TypeOf(_Py_CAST([*c]PyCMethodObject, func)) {
    _ = &func;
    return blk_1: {
        _ = assert(PyCMethod_Check(func));
        break :blk_1 _Py_CAST([*c]PyCMethodObject, func);
    };
}
pub inline fn PyCMethod_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyCMethod_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyCMethod_Type);
}
pub inline fn PyCMethod_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyCMethod_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyCMethod_Type);
}
pub const Py_MODULEOBJECT_H = "";
pub inline fn PyModule_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyModule_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyModule_Type);
}
pub inline fn PyModule_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyModule_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyModule_Type);
}
pub const PyModuleDef_HEAD_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/moduleobject.h:60:9
pub const Py_mod_create = @as(c_int, 1);
pub const Py_mod_exec = @as(c_int, 2);
pub const Py_mod_multiple_interpreters = @as(c_int, 3);
pub const Py_mod_gil = @as(c_int, 4);
pub const _Py_mod_LAST_SLOT = @as(c_int, 4);
pub const Py_MOD_MULTIPLE_INTERPRETERS_NOT_SUPPORTED = __helpers.cast(?*anyopaque, @as(c_int, 0));
pub const Py_MOD_MULTIPLE_INTERPRETERS_SUPPORTED = __helpers.cast(?*anyopaque, @as(c_int, 1));
pub const Py_MOD_PER_INTERPRETER_GIL_SUPPORTED = __helpers.cast(?*anyopaque, @as(c_int, 2));
pub const Py_MOD_GIL_USED = __helpers.cast(?*anyopaque, @as(c_int, 0));
pub const Py_MOD_GIL_NOT_USED = __helpers.cast(?*anyopaque, @as(c_int, 1));
pub const Py_MONITORING_H = "";
pub const PY_MONITORING_EVENT_PY_START = @as(c_int, 0);
pub const PY_MONITORING_EVENT_PY_RESUME = @as(c_int, 1);
pub const PY_MONITORING_EVENT_PY_RETURN = @as(c_int, 2);
pub const PY_MONITORING_EVENT_PY_YIELD = @as(c_int, 3);
pub const PY_MONITORING_EVENT_CALL = @as(c_int, 4);
pub const PY_MONITORING_EVENT_LINE = @as(c_int, 5);
pub const PY_MONITORING_EVENT_INSTRUCTION = @as(c_int, 6);
pub const PY_MONITORING_EVENT_JUMP = @as(c_int, 7);
pub const PY_MONITORING_EVENT_BRANCH_LEFT = @as(c_int, 8);
pub const PY_MONITORING_EVENT_BRANCH_RIGHT = @as(c_int, 9);
pub const PY_MONITORING_EVENT_STOP_ITERATION = @as(c_int, 10);
pub const PY_MONITORING_IS_INSTRUMENTED_EVENT = @compileError("unable to translate macro: undefined identifier `_PY_MONITORING_LOCAL_EVENTS`"); // /usr/include/python3.14/cpython/monitoring.h:20:9
pub const PY_MONITORING_EVENT_RAISE = @as(c_int, 11);
pub const PY_MONITORING_EVENT_EXCEPTION_HANDLED = @as(c_int, 12);
pub const PY_MONITORING_EVENT_PY_UNWIND = @as(c_int, 13);
pub const PY_MONITORING_EVENT_PY_THROW = @as(c_int, 14);
pub const PY_MONITORING_EVENT_RERAISE = @as(c_int, 15);
pub const PY_MONITORING_EVENT_C_RETURN = @as(c_int, 16);
pub const PY_MONITORING_EVENT_C_RAISE = @as(c_int, 17);
pub const PY_MONITORING_EVENT_BRANCH = @as(c_int, 18);
pub const Py_FUNCOBJECT_H = "";
pub inline fn PyFunction_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyFunction_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyFunction_Type);
}
pub inline fn _PyFunction_CAST(func: anytype) @TypeOf(_Py_CAST([*c]PyFunctionObject, func)) {
    _ = &func;
    return blk_1: {
        _ = assert(PyFunction_Check(func));
        break :blk_1 _Py_CAST([*c]PyFunctionObject, func);
    };
}
pub const PY_FOREACH_FUNC_EVENT = @compileError("unable to translate macro: undefined identifier `CREATE`"); // /usr/include/python3.14/cpython/funcobject.h:132:9
pub const Py_CLASSOBJECT_H = "";
pub inline fn PyMethod_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyMethod_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyMethod_Type);
}
pub inline fn _PyMethod_CAST(meth: anytype) @TypeOf(_Py_CAST([*c]PyMethodObject, meth)) {
    _ = &meth;
    return blk_1: {
        _ = assert(PyMethod_Check(meth));
        break :blk_1 _Py_CAST([*c]PyMethodObject, meth);
    };
}
pub inline fn PyInstanceMethod_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyInstanceMethod_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyInstanceMethod_Type);
}
pub inline fn _PyInstanceMethod_CAST(meth: anytype) @TypeOf(_Py_CAST([*c]PyInstanceMethodObject, meth)) {
    _ = &meth;
    return blk_1: {
        _ = assert(PyInstanceMethod_Check(meth));
        break :blk_1 _Py_CAST([*c]PyInstanceMethodObject, meth);
    };
}
pub const Py_FILEOBJECT_H = "";
pub const PY_STDIOTEXTMODE = "b";
pub const Py_CAPSULE_H = "";
pub inline fn PyCapsule_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyCapsule_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyCapsule_Type);
}
pub const Py_CODE_H = "";
pub inline fn _PyCode_DEF_THREAD_LOCAL_BYTECODE() void {
    return;
}
pub const _PyCode_DEF = @compileError("unable to translate macro: undefined identifier `co_consts`"); // /usr/include/python3.14/cpython/code.h:45:9
pub const CO_OPTIMIZED = @as(c_int, 0x0001);
pub const CO_NEWLOCALS = @as(c_int, 0x0002);
pub const CO_VARARGS = @as(c_int, 0x0004);
pub const CO_VARKEYWORDS = @as(c_int, 0x0008);
pub const CO_NESTED = @as(c_int, 0x0010);
pub const CO_GENERATOR = @as(c_int, 0x0020);
pub const CO_COROUTINE = @as(c_int, 0x0080);
pub const CO_ITERABLE_COROUTINE = @as(c_int, 0x0100);
pub const CO_ASYNC_GENERATOR = @as(c_int, 0x0200);
pub const CO_FUTURE_DIVISION = __helpers.promoteIntLiteral(c_int, 0x20000, .hex);
pub const CO_FUTURE_ABSOLUTE_IMPORT = __helpers.promoteIntLiteral(c_int, 0x40000, .hex);
pub const CO_FUTURE_WITH_STATEMENT = __helpers.promoteIntLiteral(c_int, 0x80000, .hex);
pub const CO_FUTURE_PRINT_FUNCTION = __helpers.promoteIntLiteral(c_int, 0x100000, .hex);
pub const CO_FUTURE_UNICODE_LITERALS = __helpers.promoteIntLiteral(c_int, 0x200000, .hex);
pub const CO_FUTURE_BARRY_AS_BDFL = __helpers.promoteIntLiteral(c_int, 0x400000, .hex);
pub const CO_FUTURE_GENERATOR_STOP = __helpers.promoteIntLiteral(c_int, 0x800000, .hex);
pub const CO_FUTURE_ANNOTATIONS = __helpers.promoteIntLiteral(c_int, 0x1000000, .hex);
pub const CO_NO_MONITORING_EVENTS = __helpers.promoteIntLiteral(c_int, 0x2000000, .hex);
pub const CO_HAS_DOCSTRING = __helpers.promoteIntLiteral(c_int, 0x4000000, .hex);
pub const CO_METHOD = __helpers.promoteIntLiteral(c_int, 0x8000000, .hex);
pub const PY_PARSER_REQUIRES_FUTURE_KEYWORD = "";
pub const CO_MAXBLOCKS = @as(c_int, 21);
pub inline fn PyCode_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyCode_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyCode_Type);
}
pub const PY_FOREACH_CODE_EVENT = @compileError("unable to translate macro: undefined identifier `CREATE`"); // /usr/include/python3.14/cpython/code.h:226:9
pub const Py_PYFRAME_H = "";
pub inline fn PyFrame_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyFrame_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyFrame_Type);
}
pub inline fn PyFrameLocalsProxy_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyFrameLocalsProxy_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyFrameLocalsProxy_Type);
}
pub const PyUnstable_EXECUTABLE_KIND_SKIP = @as(c_int, 0);
pub const PyUnstable_EXECUTABLE_KIND_PY_FUNCTION = @as(c_int, 1);
pub const PyUnstable_EXECUTABLE_KIND_BUILTIN_FUNCTION = @as(c_int, 3);
pub const PyUnstable_EXECUTABLE_KIND_METHOD_DESCRIPTOR = @as(c_int, 4);
pub const PyUnstable_EXECUTABLE_KINDS = @as(c_int, 5);
pub const Py_TRACEBACK_H = "";
pub inline fn PyTraceBack_Check(v: anytype) @TypeOf(Py_IS_TYPE(v, &PyTraceBack_Type)) {
    _ = &v;
    return Py_IS_TYPE(v, &PyTraceBack_Type);
}
pub const Py_SLICEOBJECT_H = "";
// /usr/include/python3.14/sliceobject.h:14:11: warning: macro 'Py_Ellipsis' contains a runtime value, translated to function
pub inline fn Py_Ellipsis() @TypeOf(&_Py_EllipsisObject) {
    return &_Py_EllipsisObject;
}
pub inline fn PySlice_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PySlice_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PySlice_Type);
}
pub const Py_CELLOBJECT_H = "";
pub inline fn PyCell_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyCell_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyCell_Type);
}
pub const Py_ITEROBJECT_H = "";
pub inline fn PySeqIter_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PySeqIter_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PySeqIter_Type);
}
pub inline fn PyCallIter_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyCallIter_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyCallIter_Type);
}
pub const Py_PYCORECONFIG_H = "";
pub const Py_PYSTATE_H = "";
pub const MAX_CO_EXTRA_USERS = @as(c_int, 255);
pub inline fn PyThreadState_GET() @TypeOf(PyThreadState_Get()) {
    return PyThreadState_Get();
}
pub const PyTrace_CALL = @as(c_int, 0);
pub const PyTrace_EXCEPTION = @as(c_int, 1);
pub const PyTrace_LINE = @as(c_int, 2);
pub const PyTrace_RETURN = @as(c_int, 3);
pub const PyTrace_C_CALL = @as(c_int, 4);
pub const PyTrace_C_EXCEPTION = @as(c_int, 5);
pub const PyTrace_C_RETURN = @as(c_int, 6);
pub const PyTrace_OPCODE = @as(c_int, 7);
pub const _Py_MAX_SCRIPT_PATH_SIZE = @as(c_int, 512);
pub const _PY_DATA_STACK_CHUNK_SIZE = @as(c_int, 16) * @as(c_int, 1024);
pub const Py_GENOBJECT_H = "";
pub inline fn PyGen_Check(op: anytype) @TypeOf(PyObject_TypeCheck(op, &PyGen_Type)) {
    _ = &op;
    return PyObject_TypeCheck(op, &PyGen_Type);
}
pub inline fn PyGen_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyGen_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyGen_Type);
}
pub inline fn PyCoro_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyCoro_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyCoro_Type);
}
pub inline fn PyAsyncGen_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyAsyncGen_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyAsyncGen_Type);
}
pub inline fn PyAsyncGenASend_CheckExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &_PyAsyncGenASend_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &_PyAsyncGenASend_Type);
}
pub const Py_DESCROBJECT_H = "";
pub const Py_T_SHORT = @as(c_int, 0);
pub const Py_T_INT = @as(c_int, 1);
pub const Py_T_LONG = @as(c_int, 2);
pub const Py_T_FLOAT = @as(c_int, 3);
pub const Py_T_DOUBLE = @as(c_int, 4);
pub const Py_T_STRING = @as(c_int, 5);
pub const _Py_T_OBJECT = @as(c_int, 6);
pub const Py_T_CHAR = @as(c_int, 7);
pub const Py_T_BYTE = @as(c_int, 8);
pub const Py_T_UBYTE = @as(c_int, 9);
pub const Py_T_USHORT = @as(c_int, 10);
pub const Py_T_UINT = @as(c_int, 11);
pub const Py_T_ULONG = @as(c_int, 12);
pub const Py_T_STRING_INPLACE = @as(c_int, 13);
pub const Py_T_BOOL = @as(c_int, 14);
pub const Py_T_OBJECT_EX = @as(c_int, 16);
pub const Py_T_LONGLONG = @as(c_int, 17);
pub const Py_T_ULONGLONG = @as(c_int, 18);
pub const Py_T_PYSSIZET = @as(c_int, 19);
pub const _Py_T_NONE = @as(c_int, 20);
pub const Py_READONLY = @as(c_int, 1);
pub const Py_AUDIT_READ = @as(c_int, 2);
pub const _Py_WRITE_RESTRICTED = @as(c_int, 4);
pub const Py_RELATIVE_OFFSET = @as(c_int, 8);
pub const PyWrapperFlag_KEYWORDS = @as(c_int, 1);
pub const PyDescr_COMMON = @compileError("unable to translate macro: undefined identifier `d_common`"); // /usr/include/python3.14/cpython/descrobject.h:33:9
pub inline fn PyDescr_TYPE(x: anytype) @TypeOf(__helpers.cast([*c]PyDescrObject, x).*.d_type) {
    _ = &x;
    return __helpers.cast([*c]PyDescrObject, x).*.d_type;
}
pub inline fn PyDescr_NAME(x: anytype) @TypeOf(__helpers.cast([*c]PyDescrObject, x).*.d_name) {
    _ = &x;
    return __helpers.cast([*c]PyDescrObject, x).*.d_name;
}
pub const Py_GENERICALIASOBJECT_H = "";
pub const Py_WARNINGS_H = "";
pub inline fn PyErr_Warn(category: anytype, msg: anytype) @TypeOf(PyErr_WarnEx(category, msg, @as(c_int, 1))) {
    _ = &category;
    _ = &msg;
    return PyErr_WarnEx(category, msg, @as(c_int, 1));
}
pub const Py_WEAKREFOBJECT_H = "";
pub inline fn PyWeakref_CheckRef(op: anytype) @TypeOf(PyObject_TypeCheck(op, &_PyWeakref_RefType)) {
    _ = &op;
    return PyObject_TypeCheck(op, &_PyWeakref_RefType);
}
pub inline fn PyWeakref_CheckRefExact(op: anytype) @TypeOf(Py_IS_TYPE(op, &_PyWeakref_RefType)) {
    _ = &op;
    return Py_IS_TYPE(op, &_PyWeakref_RefType);
}
pub inline fn PyWeakref_CheckProxy(op: anytype) @TypeOf((Py_IS_TYPE(op, &_PyWeakref_ProxyType) != 0) or (Py_IS_TYPE(op, &_PyWeakref_CallableProxyType) != 0)) {
    _ = &op;
    return (Py_IS_TYPE(op, &_PyWeakref_ProxyType) != 0) or (Py_IS_TYPE(op, &_PyWeakref_CallableProxyType) != 0);
}
pub inline fn PyWeakref_Check(op: anytype) @TypeOf((PyWeakref_CheckRef(op) != 0) or (PyWeakref_CheckProxy(op) != 0)) {
    _ = &op;
    return (PyWeakref_CheckRef(op) != 0) or (PyWeakref_CheckProxy(op) != 0);
}
pub inline fn _PyWeakref_CAST(op: anytype) @TypeOf(_Py_CAST([*c]PyWeakReference, op)) {
    _ = &op;
    return blk_1: {
        _ = assert(PyWeakref_Check(op));
        break :blk_1 _Py_CAST([*c]PyWeakReference, op);
    };
}
pub const Py_STRUCTSEQ_H = "";
pub const PyStructSequence_SET_ITEM = PyStructSequence_SetItem;
pub const PyStructSequence_GET_ITEM = PyStructSequence_GetItem;
pub const Py_PICKLEBUFOBJECT_H = "";
pub inline fn PyPickleBuffer_Check(op: anytype) @TypeOf(Py_IS_TYPE(op, &PyPickleBuffer_Type)) {
    _ = &op;
    return Py_IS_TYPE(op, &PyPickleBuffer_Type);
}
pub const Py_PYTIME_H = "";
pub const PyTime_MIN = INT64_MIN;
pub const PyTime_MAX = INT64_MAX;
pub const Py_CODECREGISTRY_H = "";
pub const Py_PYTHREAD_H = "";
pub const PY_HAVE_THREAD_NATIVE_ID = "";
pub const WAIT_LOCK = @as(c_int, 1);
pub const NOWAIT_LOCK = @as(c_int, 0);
pub const PY_TIMEOUT_T = c_longlong;
pub const PYTHREAD_INVALID_THREAD_ID = __helpers.cast(c_ulong, -@as(c_int, 1));
pub const _PTHREAD_H = @as(c_int, 1);
pub const _SCHED_H = @as(c_int, 1);
pub const _BITS_SCHED_H = @as(c_int, 1);
pub const SCHED_OTHER = @as(c_int, 0);
pub const SCHED_FIFO = @as(c_int, 1);
pub const SCHED_RR = @as(c_int, 2);
pub const SCHED_BATCH = @as(c_int, 3);
pub const SCHED_ISO = @as(c_int, 4);
pub const SCHED_IDLE = @as(c_int, 5);
pub const SCHED_DEADLINE = @as(c_int, 6);
pub const SCHED_RESET_ON_FORK = __helpers.promoteIntLiteral(c_int, 0x40000000, .hex);
pub const CSIGNAL = @as(c_int, 0x000000ff);
pub const CLONE_VM = @as(c_int, 0x00000100);
pub const CLONE_FS = @as(c_int, 0x00000200);
pub const CLONE_FILES = @as(c_int, 0x00000400);
pub const CLONE_SIGHAND = @as(c_int, 0x00000800);
pub const CLONE_PIDFD = @as(c_int, 0x00001000);
pub const CLONE_PTRACE = @as(c_int, 0x00002000);
pub const CLONE_VFORK = @as(c_int, 0x00004000);
pub const CLONE_PARENT = __helpers.promoteIntLiteral(c_int, 0x00008000, .hex);
pub const CLONE_THREAD = __helpers.promoteIntLiteral(c_int, 0x00010000, .hex);
pub const CLONE_NEWNS = __helpers.promoteIntLiteral(c_int, 0x00020000, .hex);
pub const CLONE_SYSVSEM = __helpers.promoteIntLiteral(c_int, 0x00040000, .hex);
pub const CLONE_SETTLS = __helpers.promoteIntLiteral(c_int, 0x00080000, .hex);
pub const CLONE_PARENT_SETTID = __helpers.promoteIntLiteral(c_int, 0x00100000, .hex);
pub const CLONE_CHILD_CLEARTID = __helpers.promoteIntLiteral(c_int, 0x00200000, .hex);
pub const CLONE_DETACHED = __helpers.promoteIntLiteral(c_int, 0x00400000, .hex);
pub const CLONE_UNTRACED = __helpers.promoteIntLiteral(c_int, 0x00800000, .hex);
pub const CLONE_CHILD_SETTID = __helpers.promoteIntLiteral(c_int, 0x01000000, .hex);
pub const CLONE_NEWCGROUP = __helpers.promoteIntLiteral(c_int, 0x02000000, .hex);
pub const CLONE_NEWUTS = __helpers.promoteIntLiteral(c_int, 0x04000000, .hex);
pub const CLONE_NEWIPC = __helpers.promoteIntLiteral(c_int, 0x08000000, .hex);
pub const CLONE_NEWUSER = __helpers.promoteIntLiteral(c_int, 0x10000000, .hex);
pub const CLONE_NEWPID = __helpers.promoteIntLiteral(c_int, 0x20000000, .hex);
pub const CLONE_NEWNET = __helpers.promoteIntLiteral(c_int, 0x40000000, .hex);
pub const CLONE_IO = __helpers.promoteIntLiteral(c_int, 0x80000000, .hex);
pub const CLONE_NEWTIME = @as(c_int, 0x00000080);
pub const _BITS_TYPES_STRUCT_SCHED_PARAM = @as(c_int, 1);
pub const _BITS_CPU_SET_H = @as(c_int, 1);
pub const __CPU_SETSIZE = @as(c_int, 1024);
pub const __NCPUBITS = @as(c_int, 8) * __helpers.sizeof(__cpu_mask);
pub inline fn __CPUELT(cpu: anytype) @TypeOf(__helpers.div(cpu, __NCPUBITS)) {
    _ = &cpu;
    return __helpers.div(cpu, __NCPUBITS);
}
pub inline fn __CPUMASK(cpu: anytype) @TypeOf(__helpers.cast(__cpu_mask, @as(c_int, 1)) << __helpers.rem(cpu, __NCPUBITS)) {
    _ = &cpu;
    return __helpers.cast(__cpu_mask, @as(c_int, 1)) << __helpers.rem(cpu, __NCPUBITS);
}
pub const __CPU_ZERO_S = @compileError("unable to translate C expr: unexpected token 'do'"); // /usr/include/x86_64-linux-gnu/bits/cpu-set.h:46:10
pub const __CPU_SET_S = @compileError("unable to translate macro: undefined identifier `__cpu`"); // /usr/include/x86_64-linux-gnu/bits/cpu-set.h:58:9
pub const __CPU_CLR_S = @compileError("unable to translate macro: undefined identifier `__cpu`"); // /usr/include/x86_64-linux-gnu/bits/cpu-set.h:65:9
pub const __CPU_ISSET_S = @compileError("unable to translate macro: undefined identifier `__cpu`"); // /usr/include/x86_64-linux-gnu/bits/cpu-set.h:72:9
pub inline fn __CPU_COUNT_S(setsize: anytype, cpusetp: anytype) @TypeOf(__sched_cpucount(setsize, cpusetp)) {
    _ = &setsize;
    _ = &cpusetp;
    return __sched_cpucount(setsize, cpusetp);
}
pub const __CPU_EQUAL_S = @compileError("unable to translate macro: undefined identifier `__builtin_memcmp`"); // /usr/include/x86_64-linux-gnu/bits/cpu-set.h:84:10
pub const __CPU_OP_S = @compileError("unable to translate macro: undefined identifier `__dest`"); // /usr/include/x86_64-linux-gnu/bits/cpu-set.h:99:9
pub inline fn __CPU_ALLOC_SIZE(count: anytype) @TypeOf(__helpers.div((count + __NCPUBITS) - @as(c_int, 1), __NCPUBITS) * __helpers.sizeof(__cpu_mask)) {
    _ = &count;
    return __helpers.div((count + __NCPUBITS) - @as(c_int, 1), __NCPUBITS) * __helpers.sizeof(__cpu_mask);
}
pub inline fn __CPU_ALLOC(count: anytype) @TypeOf(__sched_cpualloc(count)) {
    _ = &count;
    return __sched_cpualloc(count);
}
pub inline fn __CPU_FREE(cpuset: anytype) @TypeOf(__sched_cpufree(cpuset)) {
    _ = &cpuset;
    return __sched_cpufree(cpuset);
}
pub const sched_priority = @compileError("unable to translate macro: undefined identifier `sched_priority`"); // /usr/include/sched.h:47:9
pub const __sched_priority = sched_priority;
pub const CPU_SETSIZE = __CPU_SETSIZE;
pub inline fn CPU_SET(cpu: anytype, cpusetp: anytype) @TypeOf(__CPU_SET_S(cpu, __helpers.sizeof(cpu_set_t), cpusetp)) {
    _ = &cpu;
    _ = &cpusetp;
    return __CPU_SET_S(cpu, __helpers.sizeof(cpu_set_t), cpusetp);
}
pub inline fn CPU_CLR(cpu: anytype, cpusetp: anytype) @TypeOf(__CPU_CLR_S(cpu, __helpers.sizeof(cpu_set_t), cpusetp)) {
    _ = &cpu;
    _ = &cpusetp;
    return __CPU_CLR_S(cpu, __helpers.sizeof(cpu_set_t), cpusetp);
}
pub inline fn CPU_ISSET(cpu: anytype, cpusetp: anytype) @TypeOf(__CPU_ISSET_S(cpu, __helpers.sizeof(cpu_set_t), cpusetp)) {
    _ = &cpu;
    _ = &cpusetp;
    return __CPU_ISSET_S(cpu, __helpers.sizeof(cpu_set_t), cpusetp);
}
pub inline fn CPU_ZERO(cpusetp: anytype) @TypeOf(__CPU_ZERO_S(__helpers.sizeof(cpu_set_t), cpusetp)) {
    _ = &cpusetp;
    return __CPU_ZERO_S(__helpers.sizeof(cpu_set_t), cpusetp);
}
pub inline fn CPU_COUNT(cpusetp: anytype) @TypeOf(__CPU_COUNT_S(__helpers.sizeof(cpu_set_t), cpusetp)) {
    _ = &cpusetp;
    return __CPU_COUNT_S(__helpers.sizeof(cpu_set_t), cpusetp);
}
pub inline fn CPU_SET_S(cpu: anytype, setsize: anytype, cpusetp: anytype) @TypeOf(__CPU_SET_S(cpu, setsize, cpusetp)) {
    _ = &cpu;
    _ = &setsize;
    _ = &cpusetp;
    return __CPU_SET_S(cpu, setsize, cpusetp);
}
pub inline fn CPU_CLR_S(cpu: anytype, setsize: anytype, cpusetp: anytype) @TypeOf(__CPU_CLR_S(cpu, setsize, cpusetp)) {
    _ = &cpu;
    _ = &setsize;
    _ = &cpusetp;
    return __CPU_CLR_S(cpu, setsize, cpusetp);
}
pub inline fn CPU_ISSET_S(cpu: anytype, setsize: anytype, cpusetp: anytype) @TypeOf(__CPU_ISSET_S(cpu, setsize, cpusetp)) {
    _ = &cpu;
    _ = &setsize;
    _ = &cpusetp;
    return __CPU_ISSET_S(cpu, setsize, cpusetp);
}
pub inline fn CPU_ZERO_S(setsize: anytype, cpusetp: anytype) @TypeOf(__CPU_ZERO_S(setsize, cpusetp)) {
    _ = &setsize;
    _ = &cpusetp;
    return __CPU_ZERO_S(setsize, cpusetp);
}
pub inline fn CPU_COUNT_S(setsize: anytype, cpusetp: anytype) @TypeOf(__CPU_COUNT_S(setsize, cpusetp)) {
    _ = &setsize;
    _ = &cpusetp;
    return __CPU_COUNT_S(setsize, cpusetp);
}
pub inline fn CPU_EQUAL(cpusetp1: anytype, cpusetp2: anytype) @TypeOf(__CPU_EQUAL_S(__helpers.sizeof(cpu_set_t), cpusetp1, cpusetp2)) {
    _ = &cpusetp1;
    _ = &cpusetp2;
    return __CPU_EQUAL_S(__helpers.sizeof(cpu_set_t), cpusetp1, cpusetp2);
}
pub inline fn CPU_EQUAL_S(setsize: anytype, cpusetp1: anytype, cpusetp2: anytype) @TypeOf(__CPU_EQUAL_S(setsize, cpusetp1, cpusetp2)) {
    _ = &setsize;
    _ = &cpusetp1;
    _ = &cpusetp2;
    return __CPU_EQUAL_S(setsize, cpusetp1, cpusetp2);
}
pub const CPU_AND = @compileError("unable to translate C expr: unexpected token ')'"); // /usr/include/sched.h:111:10
pub const CPU_OR = @compileError("unable to translate C expr: unexpected token '|'"); // /usr/include/sched.h:113:10
pub const CPU_XOR = @compileError("unable to translate C expr: unexpected token '^'"); // /usr/include/sched.h:115:10
pub const CPU_AND_S = @compileError("unable to translate C expr: unexpected token ')'"); // /usr/include/sched.h:117:10
pub const CPU_OR_S = @compileError("unable to translate C expr: unexpected token '|'"); // /usr/include/sched.h:119:10
pub const CPU_XOR_S = @compileError("unable to translate C expr: unexpected token '^'"); // /usr/include/sched.h:121:10
pub inline fn CPU_ALLOC_SIZE(count: anytype) @TypeOf(__CPU_ALLOC_SIZE(count)) {
    _ = &count;
    return __CPU_ALLOC_SIZE(count);
}
pub inline fn CPU_ALLOC(count: anytype) @TypeOf(__CPU_ALLOC(count)) {
    _ = &count;
    return __CPU_ALLOC(count);
}
pub inline fn CPU_FREE(cpuset: anytype) @TypeOf(__CPU_FREE(cpuset)) {
    _ = &cpuset;
    return __CPU_FREE(cpuset);
}
pub const _TIME_H = @as(c_int, 1);
pub const _BITS_TIME_H = @as(c_int, 1);
pub const CLOCKS_PER_SEC = __helpers.cast(__clock_t, __helpers.promoteIntLiteral(c_int, 1000000, .decimal));
pub const CLOCK_REALTIME = @as(c_int, 0);
pub const CLOCK_MONOTONIC = @as(c_int, 1);
pub const CLOCK_PROCESS_CPUTIME_ID = @as(c_int, 2);
pub const CLOCK_THREAD_CPUTIME_ID = @as(c_int, 3);
pub const CLOCK_MONOTONIC_RAW = @as(c_int, 4);
pub const CLOCK_REALTIME_COARSE = @as(c_int, 5);
pub const CLOCK_MONOTONIC_COARSE = @as(c_int, 6);
pub const CLOCK_BOOTTIME = @as(c_int, 7);
pub const CLOCK_REALTIME_ALARM = @as(c_int, 8);
pub const CLOCK_BOOTTIME_ALARM = @as(c_int, 9);
pub const CLOCK_TAI = @as(c_int, 11);
pub const TIMER_ABSTIME = @as(c_int, 1);
pub const _BITS_TIMEX_H = @as(c_int, 1);
pub const ADJ_OFFSET = @as(c_int, 0x0001);
pub const ADJ_FREQUENCY = @as(c_int, 0x0002);
pub const ADJ_MAXERROR = @as(c_int, 0x0004);
pub const ADJ_ESTERROR = @as(c_int, 0x0008);
pub const ADJ_STATUS = @as(c_int, 0x0010);
pub const ADJ_TIMECONST = @as(c_int, 0x0020);
pub const ADJ_TAI = @as(c_int, 0x0080);
pub const ADJ_SETOFFSET = @as(c_int, 0x0100);
pub const ADJ_MICRO = @as(c_int, 0x1000);
pub const ADJ_NANO = @as(c_int, 0x2000);
pub const ADJ_TICK = @as(c_int, 0x4000);
pub const ADJ_OFFSET_SINGLESHOT = __helpers.promoteIntLiteral(c_int, 0x8001, .hex);
pub const ADJ_OFFSET_SS_READ = __helpers.promoteIntLiteral(c_int, 0xa001, .hex);
pub const MOD_OFFSET = ADJ_OFFSET;
pub const MOD_FREQUENCY = ADJ_FREQUENCY;
pub const MOD_MAXERROR = ADJ_MAXERROR;
pub const MOD_ESTERROR = ADJ_ESTERROR;
pub const MOD_STATUS = ADJ_STATUS;
pub const MOD_TIMECONST = ADJ_TIMECONST;
pub const MOD_CLKB = ADJ_TICK;
pub const MOD_CLKA = ADJ_OFFSET_SINGLESHOT;
pub const MOD_TAI = ADJ_TAI;
pub const MOD_MICRO = ADJ_MICRO;
pub const MOD_NANO = ADJ_NANO;
pub const STA_PLL = @as(c_int, 0x0001);
pub const STA_PPSFREQ = @as(c_int, 0x0002);
pub const STA_PPSTIME = @as(c_int, 0x0004);
pub const STA_FLL = @as(c_int, 0x0008);
pub const STA_INS = @as(c_int, 0x0010);
pub const STA_DEL = @as(c_int, 0x0020);
pub const STA_UNSYNC = @as(c_int, 0x0040);
pub const STA_FREQHOLD = @as(c_int, 0x0080);
pub const STA_PPSSIGNAL = @as(c_int, 0x0100);
pub const STA_PPSJITTER = @as(c_int, 0x0200);
pub const STA_PPSWANDER = @as(c_int, 0x0400);
pub const STA_PPSERROR = @as(c_int, 0x0800);
pub const STA_CLOCKERR = @as(c_int, 0x1000);
pub const STA_NANO = @as(c_int, 0x2000);
pub const STA_MODE = @as(c_int, 0x4000);
pub const STA_CLK = __helpers.promoteIntLiteral(c_int, 0x8000, .hex);
pub const STA_RONLY = ((((((STA_PPSSIGNAL | STA_PPSJITTER) | STA_PPSWANDER) | STA_PPSERROR) | STA_CLOCKERR) | STA_NANO) | STA_MODE) | STA_CLK;
pub const __struct_tm_defined = @as(c_int, 1);
pub const __itimerspec_defined = @as(c_int, 1);
pub const TIME_UTC = @as(c_int, 1);
pub inline fn __isleap(year: anytype) @TypeOf((__helpers.rem(year, @as(c_int, 4)) == @as(c_int, 0)) and ((__helpers.rem(year, @as(c_int, 100)) != @as(c_int, 0)) or (__helpers.rem(year, @as(c_int, 400)) == @as(c_int, 0)))) {
    _ = &year;
    return (__helpers.rem(year, @as(c_int, 4)) == @as(c_int, 0)) and ((__helpers.rem(year, @as(c_int, 100)) != @as(c_int, 0)) or (__helpers.rem(year, @as(c_int, 400)) == @as(c_int, 0)));
}
pub const _BITS_SETJMP_H = @as(c_int, 1);
pub const __jmp_buf_tag_defined = @as(c_int, 1);
pub const PTHREAD_MUTEX_INITIALIZER = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/pthread.h:90:9
pub const PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/pthread.h:93:10
pub const PTHREAD_ERRORCHECK_MUTEX_INITIALIZER_NP = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/pthread.h:95:10
pub const PTHREAD_ADAPTIVE_MUTEX_INITIALIZER_NP = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/pthread.h:97:10
pub const PTHREAD_RWLOCK_INITIALIZER = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/pthread.h:114:10
pub const PTHREAD_RWLOCK_WRITER_NONRECURSIVE_INITIALIZER_NP = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/pthread.h:117:11
pub const PTHREAD_COND_INITIALIZER = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/pthread.h:155:9
pub const PTHREAD_CANCELED = __helpers.cast(?*anyopaque, -@as(c_int, 1));
pub const PTHREAD_ONCE_INIT = @as(c_int, 0);
pub const PTHREAD_BARRIER_SERIAL_THREAD = -@as(c_int, 1);
pub const PTHREAD_ATTR_NO_SIGMASK_NP = -@as(c_int, 1);
pub const __cleanup_fct_attribute = "";
pub const pthread_cleanup_push = @compileError("unable to translate macro: undefined identifier `__cancel_buf`"); // /usr/include/pthread.h:681:10
pub const pthread_cleanup_pop = @compileError("unable to translate macro: undefined identifier `__cancel_buf`"); // /usr/include/pthread.h:702:10
pub const pthread_cleanup_push_defer_np = @compileError("unable to translate macro: undefined identifier `__cancel_buf`"); // /usr/include/pthread.h:716:11
pub const pthread_cleanup_pop_restore_np = @compileError("unable to translate macro: undefined identifier `__cancel_buf`"); // /usr/include/pthread.h:738:11
pub inline fn __sigsetjmp_cancel(env: anytype, savemask: anytype) @TypeOf(__sigsetjmp(__helpers.cast([*c]struct___jmp_buf_tag, __helpers.cast(?*anyopaque, env)), savemask)) {
    _ = &env;
    _ = &savemask;
    return __sigsetjmp(__helpers.cast([*c]struct___jmp_buf_tag, __helpers.cast(?*anyopaque, env)), savemask);
}
pub const Py_tss_NEEDS_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/cpython/pythread.h:43:9
pub const Py_CONTEXT_H = "";
pub inline fn PyContext_CheckExact(o: anytype) @TypeOf(Py_IS_TYPE(o, &PyContext_Type)) {
    _ = &o;
    return Py_IS_TYPE(o, &PyContext_Type);
}
pub inline fn PyContextVar_CheckExact(o: anytype) @TypeOf(Py_IS_TYPE(o, &PyContextVar_Type)) {
    _ = &o;
    return Py_IS_TYPE(o, &PyContextVar_Type);
}
pub inline fn PyContextToken_CheckExact(o: anytype) @TypeOf(Py_IS_TYPE(o, &PyContextToken_Type)) {
    _ = &o;
    return Py_IS_TYPE(o, &PyContextToken_Type);
}
pub const Py_MODSUPPORT_H = "";
pub const PyModule_AddIntMacro = @compileError("unable to translate C expr: unexpected token ''"); // /usr/include/python3.14/modsupport.h:47:9
pub const PyModule_AddStringMacro = @compileError("unable to translate C expr: unexpected token ''"); // /usr/include/python3.14/modsupport.h:48:9
pub const Py_CLEANUP_SUPPORTED = __helpers.promoteIntLiteral(c_int, 0x20000, .hex);
pub const PYTHON_API_VERSION = @as(c_int, 1013);
pub const PYTHON_API_STRING = "1013";
pub const PYTHON_ABI_VERSION = @as(c_int, 3);
pub const PYTHON_ABI_STRING = "3";
pub inline fn PyModule_Create(module: anytype) @TypeOf(PyModule_Create2(module, PYTHON_API_VERSION)) {
    _ = &module;
    return PyModule_Create2(module, PYTHON_API_VERSION);
}
pub inline fn PyModule_FromDefAndSpec(module: anytype, spec: anytype) @TypeOf(PyModule_FromDefAndSpec2(module, spec, PYTHON_API_VERSION)) {
    _ = &module;
    _ = &spec;
    return PyModule_FromDefAndSpec2(module, spec, PYTHON_API_VERSION);
}
pub const Py_COMPILE_H = "";
pub const Py_single_input = @as(c_int, 256);
pub const Py_file_input = @as(c_int, 257);
pub const Py_eval_input = @as(c_int, 258);
pub const Py_func_type_input = @as(c_int, 345);
pub const PyCF_MASK = ((((((CO_FUTURE_DIVISION | CO_FUTURE_ABSOLUTE_IMPORT) | CO_FUTURE_WITH_STATEMENT) | CO_FUTURE_PRINT_FUNCTION) | CO_FUTURE_UNICODE_LITERALS) | CO_FUTURE_BARRY_AS_BDFL) | CO_FUTURE_GENERATOR_STOP) | CO_FUTURE_ANNOTATIONS;
pub const PyCF_MASK_OBSOLETE = CO_NESTED;
pub const PyCF_SOURCE_IS_UTF8 = @as(c_int, 0x0100);
pub const PyCF_DONT_IMPLY_DEDENT = @as(c_int, 0x0200);
pub const PyCF_ONLY_AST = @as(c_int, 0x0400);
pub const PyCF_IGNORE_COOKIE = @as(c_int, 0x0800);
pub const PyCF_TYPE_COMMENTS = @as(c_int, 0x1000);
pub const PyCF_ALLOW_TOP_LEVEL_AWAIT = @as(c_int, 0x2000);
pub const PyCF_ALLOW_INCOMPLETE_INPUT = @as(c_int, 0x4000);
pub const PyCF_OPTIMIZED_AST = __helpers.promoteIntLiteral(c_int, 0x8000, .hex) | PyCF_ONLY_AST;
pub const PyCF_COMPILE_MASK = ((((PyCF_ONLY_AST | PyCF_ALLOW_TOP_LEVEL_AWAIT) | PyCF_TYPE_COMMENTS) | PyCF_DONT_IMPLY_DEDENT) | PyCF_ALLOW_INCOMPLETE_INPUT) | PyCF_OPTIMIZED_AST;
pub const _PyCompilerFlags_INIT = @import("std").mem.zeroInit(PyCompilerFlags, .{
    .cf_flags = @as(c_int, 0),
    .cf_feature_version = PY_MINOR_VERSION,
});
pub const FUTURE_NESTED_SCOPES = "nested_scopes";
pub const FUTURE_GENERATORS = "generators";
pub const FUTURE_DIVISION = "division";
pub const FUTURE_ABSOLUTE_IMPORT = "absolute_import";
pub const FUTURE_WITH_STATEMENT = "with_statement";
pub const FUTURE_PRINT_FUNCTION = "print_function";
pub const FUTURE_UNICODE_LITERALS = "unicode_literals";
pub const FUTURE_BARRY_AS_BDFL = "barry_as_FLUFL";
pub const FUTURE_GENERATOR_STOP = "generator_stop";
pub const FUTURE_ANNOTATIONS = "annotations";
pub const PY_INVALID_STACK_EFFECT = INT_MAX;
pub const Py_PYTHONRUN_H = "";
pub inline fn Py_CompileStringFlags(str: anytype, p: anytype, s: anytype, f: anytype) @TypeOf(Py_CompileStringExFlags(str, p, s, f, -@as(c_int, 1))) {
    _ = &str;
    _ = &p;
    _ = &s;
    _ = &f;
    return Py_CompileStringExFlags(str, p, s, f, -@as(c_int, 1));
}
pub const Py_PYLIFECYCLE_H = "";
pub const PyInterpreterConfig_DEFAULT_GIL = @as(c_int, 0);
pub const PyInterpreterConfig_SHARED_GIL = @as(c_int, 1);
pub const PyInterpreterConfig_OWN_GIL = @as(c_int, 2);
pub const _PyInterpreterConfig_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/cpython/pylifecycle.h:52:9
pub const _PyInterpreterConfig_LEGACY_CHECK_MULTI_INTERP_EXTENSIONS = @as(c_int, 0);
pub const _PyInterpreterConfig_LEGACY_INIT = @compileError("unable to translate C expr: unexpected token '{'"); // /usr/include/python3.14/cpython/pylifecycle.h:72:9
pub const Py_CEVAL_H = "";
pub const Py_BEGIN_ALLOW_THREADS = @compileError("unable to translate macro: undefined identifier `_save`"); // /usr/include/python3.14/ceval.h:119:9
pub const Py_BLOCK_THREADS = @compileError("unable to translate macro: undefined identifier `_save`"); // /usr/include/python3.14/ceval.h:122:9
pub const Py_UNBLOCK_THREADS = @compileError("unable to translate macro: undefined identifier `_save`"); // /usr/include/python3.14/ceval.h:123:9
pub const Py_END_ALLOW_THREADS = @compileError("unable to translate macro: undefined identifier `_save`"); // /usr/include/python3.14/ceval.h:124:9
pub const FVC_MASK = @as(c_int, 0x3);
pub const FVC_NONE = @as(c_int, 0x0);
pub const FVC_STR = @as(c_int, 0x1);
pub const FVC_REPR = @as(c_int, 0x2);
pub const FVC_ASCII = @as(c_int, 0x3);
pub const FVS_MASK = @as(c_int, 0x4);
pub const FVS_HAVE_SPEC = @as(c_int, 0x4);
pub const Py_SYSMODULE_H = "";
pub const _Py_AUDIT_H = "";
pub const Py_OSMODULE_H = "";
pub const Py_INTRCHECK_H = "";
pub const Py_IMPORT_H = "";
pub inline fn PyImport_ImportModuleEx(n: anytype, g: anytype, l: anytype, f: anytype) @TypeOf(PyImport_ImportModuleLevel(n, g, l, f, @as(c_int, 0))) {
    _ = &n;
    _ = &g;
    _ = &l;
    _ = &f;
    return PyImport_ImportModuleLevel(n, g, l, f, @as(c_int, 0));
}
pub const Py_ABSTRACTOBJECT_H = "";
pub const PY_VECTORCALL_ARGUMENTS_OFFSET = _Py_STATIC_CAST(usize, @as(c_int, 1)) << ((@as(c_int, 8) * __helpers.sizeof(usize)) - @as(c_int, 1));
pub inline fn PyMapping_DelItemString(O: anytype, K: anytype) @TypeOf(PyObject_DelItemString(O, K)) {
    _ = &O;
    _ = &K;
    return PyObject_DelItemString(O, K);
}
pub inline fn PyMapping_DelItem(O: anytype, K: anytype) @TypeOf(PyObject_DelItem(O, K)) {
    _ = &O;
    _ = &K;
    return PyObject_DelItem(O, K);
}
pub const _PyObject_Vectorcall = PyObject_Vectorcall;
pub const _PyObject_VectorcallMethod = PyObject_VectorcallMethod;
pub const _PyObject_FastCallDict = PyObject_VectorcallDict;
pub const _PyVectorcall_Function = PyVectorcall_Function;
pub const _PyObject_CallOneArg = PyObject_CallOneArg;
pub const _PyObject_CallMethodNoArgs = PyObject_CallMethodNoArgs;
pub const _PyObject_CallMethodOneArg = PyObject_CallMethodOneArg;
pub inline fn PySequence_ITEM(o: anytype, i: anytype) @TypeOf(Py_TYPE(o).*.tp_as_sequence.*.sq_item(o, i)) {
    _ = &o;
    _ = &i;
    return Py_TYPE(o).*.tp_as_sequence.*.sq_item(o, i);
}
pub inline fn PySequence_Fast_GET_SIZE(o: anytype) @TypeOf(if (__helpers.cast(bool, PyList_Check(o))) PyList_GET_SIZE(o) else PyTuple_GET_SIZE(o)) {
    _ = &o;
    return if (__helpers.cast(bool, PyList_Check(o))) PyList_GET_SIZE(o) else PyTuple_GET_SIZE(o);
}
pub inline fn PySequence_Fast_GET_ITEM(o: anytype, i: anytype) @TypeOf(if (__helpers.cast(bool, PyList_Check(o))) PyList_GET_ITEM(o, i) else PyTuple_GET_ITEM(o, i)) {
    _ = &o;
    _ = &i;
    return if (__helpers.cast(bool, PyList_Check(o))) PyList_GET_ITEM(o, i) else PyTuple_GET_ITEM(o, i);
}
pub inline fn PySequence_Fast_ITEMS(sf: anytype) @TypeOf(if (__helpers.cast(bool, PyList_Check(sf))) __helpers.cast([*c]PyListObject, sf).*.ob_item else __helpers.cast([*c]PyTupleObject, sf).*.ob_item) {
    _ = &sf;
    return if (__helpers.cast(bool, PyList_Check(sf))) __helpers.cast([*c]PyListObject, sf).*.ob_item else __helpers.cast([*c]PyTupleObject, sf).*.ob_item;
}
pub const Py_BLTINMODULE_H = "";
pub const PYCTYPE_H = "";
pub const PY_CTF_LOWER = @as(c_int, 0x01);
pub const PY_CTF_UPPER = @as(c_int, 0x02);
pub const PY_CTF_ALPHA = PY_CTF_LOWER | PY_CTF_UPPER;
pub const PY_CTF_DIGIT = @as(c_int, 0x04);
pub const PY_CTF_ALNUM = PY_CTF_ALPHA | PY_CTF_DIGIT;
pub const PY_CTF_SPACE = @as(c_int, 0x08);
pub const PY_CTF_XDIGIT = @as(c_int, 0x10);
pub inline fn Py_ISLOWER(c: anytype) @TypeOf(_Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_LOWER) {
    _ = &c;
    return _Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_LOWER;
}
pub inline fn Py_ISUPPER(c: anytype) @TypeOf(_Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_UPPER) {
    _ = &c;
    return _Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_UPPER;
}
pub inline fn Py_ISALPHA(c: anytype) @TypeOf(_Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_ALPHA) {
    _ = &c;
    return _Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_ALPHA;
}
pub inline fn Py_ISDIGIT(c: anytype) @TypeOf(_Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_DIGIT) {
    _ = &c;
    return _Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_DIGIT;
}
pub inline fn Py_ISXDIGIT(c: anytype) @TypeOf(_Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_XDIGIT) {
    _ = &c;
    return _Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_XDIGIT;
}
pub inline fn Py_ISALNUM(c: anytype) @TypeOf(_Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_ALNUM) {
    _ = &c;
    return _Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_ALNUM;
}
pub inline fn Py_ISSPACE(c: anytype) @TypeOf(_Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_SPACE) {
    _ = &c;
    return _Py_ctype_table[@as(usize, @intCast(Py_CHARMASK(c)))] & PY_CTF_SPACE;
}
pub inline fn Py_TOLOWER(c: anytype) @TypeOf(_Py_ctype_tolower[@as(usize, @intCast(Py_CHARMASK(c)))]) {
    _ = &c;
    return _Py_ctype_tolower[@as(usize, @intCast(Py_CHARMASK(c)))];
}
pub inline fn Py_TOUPPER(c: anytype) @TypeOf(_Py_ctype_toupper[@as(usize, @intCast(Py_CHARMASK(c)))]) {
    _ = &c;
    return _Py_ctype_toupper[@as(usize, @intCast(Py_CHARMASK(c)))];
}
pub const Py_STRTOD_H = "";
pub const Py_DTSF_SIGN = @as(c_int, 0x01);
pub const Py_DTSF_ADD_DOT_0 = @as(c_int, 0x02);
pub const Py_DTSF_ALT = @as(c_int, 0x04);
pub const Py_DTSF_NO_NEG_0 = @as(c_int, 0x08);
pub const Py_DTST_FINITE = @as(c_int, 0);
pub const Py_DTST_INFINITE = @as(c_int, 1);
pub const Py_DTST_NAN = @as(c_int, 2);
pub const Py_STRCMP_H = "";
pub const PyOS_strnicmp = PyOS_mystrnicmp;
pub const PyOS_stricmp = PyOS_mystricmp;
pub const Py_FILEUTILS_H = "";
pub const _SYS_STAT_H = @as(c_int, 1);
pub const _BITS_STAT_H = @as(c_int, 1);
pub const _BITS_STRUCT_STAT_H = @as(c_int, 1);
pub const st_atime = @compileError("unable to translate macro: undefined identifier `st_atim`"); // /usr/include/x86_64-linux-gnu/bits/struct_stat.h:77:11
pub const st_mtime = @compileError("unable to translate macro: undefined identifier `st_mtim`"); // /usr/include/x86_64-linux-gnu/bits/struct_stat.h:78:11
pub const st_ctime = @compileError("unable to translate macro: undefined identifier `st_ctim`"); // /usr/include/x86_64-linux-gnu/bits/struct_stat.h:79:11
pub const _STATBUF_ST_BLKSIZE = "";
pub const _STATBUF_ST_RDEV = "";
pub const _STATBUF_ST_NSEC = "";
pub const __S_IFMT = __helpers.promoteIntLiteral(c_int, 0o170000, .octal);
pub const __S_IFDIR = @as(c_int, 0o040000);
pub const __S_IFCHR = @as(c_int, 0o020000);
pub const __S_IFBLK = @as(c_int, 0o060000);
pub const __S_IFREG = __helpers.promoteIntLiteral(c_int, 0o100000, .octal);
pub const __S_IFIFO = @as(c_int, 0o010000);
pub const __S_IFLNK = __helpers.promoteIntLiteral(c_int, 0o120000, .octal);
pub const __S_IFSOCK = __helpers.promoteIntLiteral(c_int, 0o140000, .octal);
pub inline fn __S_TYPEISMQ(buf: anytype) @TypeOf(buf.*.st_mode - buf.*.st_mode) {
    _ = &buf;
    return buf.*.st_mode - buf.*.st_mode;
}
pub inline fn __S_TYPEISSEM(buf: anytype) @TypeOf(buf.*.st_mode - buf.*.st_mode) {
    _ = &buf;
    return buf.*.st_mode - buf.*.st_mode;
}
pub inline fn __S_TYPEISSHM(buf: anytype) @TypeOf(buf.*.st_mode - buf.*.st_mode) {
    _ = &buf;
    return buf.*.st_mode - buf.*.st_mode;
}
pub const __S_ISUID = @as(c_int, 0o4000);
pub const __S_ISGID = @as(c_int, 0o2000);
pub const __S_ISVTX = @as(c_int, 0o1000);
pub const __S_IREAD = @as(c_int, 0o400);
pub const __S_IWRITE = @as(c_int, 0o200);
pub const __S_IEXEC = @as(c_int, 0o100);
pub const UTIME_NOW = (@as(c_long, 1) << @as(c_int, 30)) - @as(c_long, 1);
pub const UTIME_OMIT = (@as(c_long, 1) << @as(c_int, 30)) - @as(c_long, 2);
pub const S_IFMT = __S_IFMT;
pub const S_IFDIR = __S_IFDIR;
pub const S_IFCHR = __S_IFCHR;
pub const S_IFBLK = __S_IFBLK;
pub const S_IFREG = __S_IFREG;
pub const S_IFIFO = __S_IFIFO;
pub const S_IFLNK = __S_IFLNK;
pub const S_IFSOCK = __S_IFSOCK;
pub inline fn __S_ISTYPE(mode: anytype, mask: anytype) @TypeOf((mode & __S_IFMT) == mask) {
    _ = &mode;
    _ = &mask;
    return (mode & __S_IFMT) == mask;
}
pub inline fn S_ISDIR(mode: anytype) @TypeOf(__S_ISTYPE(mode, __S_IFDIR)) {
    _ = &mode;
    return __S_ISTYPE(mode, __S_IFDIR);
}
pub inline fn S_ISCHR(mode: anytype) @TypeOf(__S_ISTYPE(mode, __S_IFCHR)) {
    _ = &mode;
    return __S_ISTYPE(mode, __S_IFCHR);
}
pub inline fn S_ISBLK(mode: anytype) @TypeOf(__S_ISTYPE(mode, __S_IFBLK)) {
    _ = &mode;
    return __S_ISTYPE(mode, __S_IFBLK);
}
pub inline fn S_ISREG(mode: anytype) @TypeOf(__S_ISTYPE(mode, __S_IFREG)) {
    _ = &mode;
    return __S_ISTYPE(mode, __S_IFREG);
}
pub inline fn S_ISFIFO(mode: anytype) @TypeOf(__S_ISTYPE(mode, __S_IFIFO)) {
    _ = &mode;
    return __S_ISTYPE(mode, __S_IFIFO);
}
pub inline fn S_ISLNK(mode: anytype) @TypeOf(__S_ISTYPE(mode, __S_IFLNK)) {
    _ = &mode;
    return __S_ISTYPE(mode, __S_IFLNK);
}
pub inline fn S_ISSOCK(mode: anytype) @TypeOf(__S_ISTYPE(mode, __S_IFSOCK)) {
    _ = &mode;
    return __S_ISTYPE(mode, __S_IFSOCK);
}
pub inline fn S_TYPEISMQ(buf: anytype) @TypeOf(__S_TYPEISMQ(buf)) {
    _ = &buf;
    return __S_TYPEISMQ(buf);
}
pub inline fn S_TYPEISSEM(buf: anytype) @TypeOf(__S_TYPEISSEM(buf)) {
    _ = &buf;
    return __S_TYPEISSEM(buf);
}
pub inline fn S_TYPEISSHM(buf: anytype) @TypeOf(__S_TYPEISSHM(buf)) {
    _ = &buf;
    return __S_TYPEISSHM(buf);
}
pub const S_ISUID = __S_ISUID;
pub const S_ISGID = __S_ISGID;
pub const S_ISVTX = __S_ISVTX;
pub const S_IRUSR = __S_IREAD;
pub const S_IWUSR = __S_IWRITE;
pub const S_IXUSR = __S_IEXEC;
pub const S_IRWXU = (__S_IREAD | __S_IWRITE) | __S_IEXEC;
pub const S_IREAD = S_IRUSR;
pub const S_IWRITE = S_IWUSR;
pub const S_IEXEC = S_IXUSR;
pub const S_IRGRP = S_IRUSR >> @as(c_int, 3);
pub const S_IWGRP = S_IWUSR >> @as(c_int, 3);
pub const S_IXGRP = S_IXUSR >> @as(c_int, 3);
pub const S_IRWXG = S_IRWXU >> @as(c_int, 3);
pub const S_IROTH = S_IRGRP >> @as(c_int, 3);
pub const S_IWOTH = S_IWGRP >> @as(c_int, 3);
pub const S_IXOTH = S_IXGRP >> @as(c_int, 3);
pub const S_IRWXO = S_IRWXG >> @as(c_int, 3);
pub const ACCESSPERMS = (S_IRWXU | S_IRWXG) | S_IRWXO;
pub const ALLPERMS = ((((S_ISUID | S_ISGID) | S_ISVTX) | S_IRWXU) | S_IRWXG) | S_IRWXO;
pub const DEFFILEMODE = ((((S_IRUSR | S_IWUSR) | S_IRGRP) | S_IWGRP) | S_IROTH) | S_IWOTH;
pub const S_BLKSIZE = @as(c_int, 512);
pub const _LINUX_STAT_H = "";
pub const _LINUX_TYPES_H = "";
pub const _ASM_GENERIC_TYPES_H = "";
pub const _ASM_GENERIC_INT_LL64_H = "";
pub const __ASM_X86_BITSPERLONG_H = "";
pub const __BITS_PER_LONG = @as(c_int, 64);
pub const __ASM_GENERIC_BITS_PER_LONG = "";
pub const _LINUX_POSIX_TYPES_H = "";
pub const _LINUX_STDDEF_H = "";
pub inline fn __struct_group_tag(TAG: anytype) @TypeOf(TAG) {
    _ = &TAG;
    return TAG;
}
pub const __struct_group = @compileError("unable to translate C expr: unexpected token 'union'"); // /usr/include/linux/stddef.h:33:9
pub const __DECLARE_FLEX_ARRAY = @compileError("unable to translate macro: undefined identifier `__empty_`"); // /usr/include/linux/stddef.h:54:9
pub inline fn __counted_by(m: anytype) void {
    _ = &m;
    return;
}
pub const __FD_SETSIZE = @as(c_int, 1024);
pub const _ASM_X86_POSIX_TYPES_64_H = "";
pub const __ASM_GENERIC_POSIX_TYPES_H = "";
pub const __bitwise = "";
pub const __bitwise__ = "";
pub const __aligned_u64 = @compileError("unable to translate macro: undefined identifier `aligned`"); // /usr/include/linux/types.h:50:9
pub const __aligned_s64 = @compileError("unable to translate macro: undefined identifier `aligned`"); // /usr/include/linux/types.h:51:9
pub const __aligned_be64 = @compileError("unable to translate macro: undefined identifier `aligned`"); // /usr/include/linux/types.h:52:9
pub const __aligned_le64 = @compileError("unable to translate macro: undefined identifier `aligned`"); // /usr/include/linux/types.h:53:9
pub const STATX_TYPE = @as(c_uint, 0x00000001);
pub const STATX_MODE = @as(c_uint, 0x00000002);
pub const STATX_NLINK = @as(c_uint, 0x00000004);
pub const STATX_UID = @as(c_uint, 0x00000008);
pub const STATX_GID = @as(c_uint, 0x00000010);
pub const STATX_ATIME = @as(c_uint, 0x00000020);
pub const STATX_MTIME = @as(c_uint, 0x00000040);
pub const STATX_CTIME = @as(c_uint, 0x00000080);
pub const STATX_INO = @as(c_uint, 0x00000100);
pub const STATX_SIZE = @as(c_uint, 0x00000200);
pub const STATX_BLOCKS = @as(c_uint, 0x00000400);
pub const STATX_BASIC_STATS = @as(c_uint, 0x000007ff);
pub const STATX_BTIME = @as(c_uint, 0x00000800);
pub const STATX_MNT_ID = @as(c_uint, 0x00001000);
pub const STATX_DIOALIGN = @as(c_uint, 0x00002000);
pub const STATX_MNT_ID_UNIQUE = @as(c_uint, 0x00004000);
pub const STATX__RESERVED = __helpers.promoteIntLiteral(c_uint, 0x80000000, .hex);
pub const STATX_ALL = @as(c_uint, 0x00000fff);
pub const STATX_ATTR_COMPRESSED = @as(c_int, 0x00000004);
pub const STATX_ATTR_IMMUTABLE = @as(c_int, 0x00000010);
pub const STATX_ATTR_APPEND = @as(c_int, 0x00000020);
pub const STATX_ATTR_NODUMP = @as(c_int, 0x00000040);
pub const STATX_ATTR_ENCRYPTED = @as(c_int, 0x00000800);
pub const STATX_ATTR_AUTOMOUNT = @as(c_int, 0x00001000);
pub const STATX_ATTR_MOUNT_ROOT = @as(c_int, 0x00002000);
pub const STATX_ATTR_VERITY = __helpers.promoteIntLiteral(c_int, 0x00100000, .hex);
pub const STATX_ATTR_DAX = __helpers.promoteIntLiteral(c_int, 0x00200000, .hex);
pub const __statx_timestamp_defined = @as(c_int, 1);
pub const __statx_defined = @as(c_int, 1);
pub const Py_PYFPE_H = "";
pub inline fn PyFPE_START_PROTECT(err_string: anytype, leave_stmt: anytype) void {
    _ = &err_string;
    _ = &leave_stmt;
    return;
}
pub inline fn PyFPE_END_PROTECT(v: anytype) void {
    _ = &v;
    return;
}
pub const Py_TRACEMALLOC_H = "";
pub const _IO_marker = struct__IO_marker;
pub const _IO_codecvt = struct__IO_codecvt;
pub const _IO_wide_data = struct__IO_wide_data;
pub const _IO_FILE = struct__IO_FILE;
pub const __locale_struct = struct___locale_struct;
pub const tm = struct_tm;
pub const timeval = struct_timeval;
pub const timespec = struct_timespec;
pub const __pthread_internal_list = struct___pthread_internal_list;
pub const __pthread_internal_slist = struct___pthread_internal_slist;
pub const __pthread_mutex_s = struct___pthread_mutex_s;
pub const __pthread_rwlock_arch_t = struct___pthread_rwlock_arch_t;
pub const __pthread_cond_s = struct___pthread_cond_s;
pub const _G_fpos_t = struct__G_fpos_t;
pub const _G_fpos64_t = struct__G_fpos64_t;
pub const _IO_cookie_io_functions_t = struct__IO_cookie_io_functions_t;
pub const obstack = struct_obstack;
pub const random_data = struct_random_data;
pub const drand48_data = struct_drand48_data;
pub const _typeobject = struct__typeobject;
pub const _object = struct__object;
pub const _longobject = struct__longobject;
pub const _frame = struct__frame;
pub const _is = struct__is;
pub const _ts = struct__ts;
pub const _specialization_cache = struct__specialization_cache;
pub const _heaptypeobject = struct__heaptypeobject;
pub const PyUnicode_Kind = enum_PyUnicode_Kind;
pub const _dictvalues = struct__dictvalues;
pub const _odictobject = struct__odictobject;
pub const _PyMonitoringState = struct__PyMonitoringState;
pub const _opaque = struct__opaque;
pub const _line_offsets = struct__line_offsets;
pub const _PyInterpreterFrame = struct__PyInterpreterFrame;
pub const _traceback = struct__traceback;
pub const _err_stackitem = struct__err_stackitem;
pub const _stack_chunk = struct__stack_chunk;
pub const _PyGenObject = struct__PyGenObject;
pub const _PyCoroObject = struct__PyCoroObject;
pub const _PyAsyncGenObject = struct__PyAsyncGenObject;
pub const wrapperbase = struct_wrapperbase;
pub const _PyWeakReference = struct__PyWeakReference;
pub const _Py_tss_t = struct__Py_tss_t;
pub const sched_param = struct_sched_param;
pub const timex = struct_timex;
pub const itimerspec = struct_itimerspec;
pub const sigevent = struct_sigevent;
pub const __jmp_buf_tag = struct___jmp_buf_tag;
pub const _pthread_cleanup_buffer = struct__pthread_cleanup_buffer;
pub const __cancel_jmp_buf_tag = struct___cancel_jmp_buf_tag;
pub const __pthread_cleanup_frame = struct___pthread_cleanup_frame;
pub const _pycontextobject = struct__pycontextobject;
pub const _pycontextvarobject = struct__pycontextvarobject;
pub const _pycontexttokenobject = struct__pycontexttokenobject;
pub const _inittab = struct__inittab;
pub const _frozen = struct__frozen;
pub const statx_timestamp = struct_statx_timestamp;
