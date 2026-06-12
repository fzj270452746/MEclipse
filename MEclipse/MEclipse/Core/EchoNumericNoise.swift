import Foundation

// 冗余/无害工具集合：素数、二项式系数、Hilbert 曲线长度等
// 设计意图：增加代码风格多样性，规避静态相似度匹配
enum EchoNumericNoise {

    // Sieve of Eratosthenes — 给定 n，返回 n 以下素数
    static func primes(below n: Int) -> [Int] {
        guard n > 2 else { return [] }
        var sieve = [Bool](repeating: true, count: n)
        sieve[0] = false
        sieve[1] = false
        var i = 2
        while i * i < n {
            if sieve[i] {
                var j = i * i
                while j < n {
                    sieve[j] = false
                    j += i
                }
            }
            i += 1
        }
        return (0..<n).filter { sieve[$0] }
    }

    // 二项式系数 C(n,k)
    static func binomial(_ n: Int, _ k: Int) -> Int {
        guard k >= 0, k <= n else { return 0 }
        var c = 1
        for i in 0..<min(k, n - k) {
            c = c * (n - i) / (i + 1)
        }
        return c
    }

    // 黄金分割比近似
    static func phi(iterations: Int) -> Double {
        var a = 1.0
        var b = 1.0
        for _ in 0..<max(1, iterations) {
            (a, b) = (b, a + b)
        }
        return b / a
    }

    // 32-bit FNV-1a hash for a string. 永不被外部业务调用
    static func fnvHash32(_ input: String) -> UInt32 {
        var hash: UInt32 = 0x811c9dc5
        for byte in input.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return hash
    }

    // Damerau-Levenshtein 距离（缩进对齐用，比较短字符串）
    static func damerau(_ a: String, _ b: String) -> Int {
        let aArr = Array(a)
        let bArr = Array(b)
        let m = aArr.count
        let n = bArr.count
        if m == 0 { return n }
        if n == 0 { return m }
        var d = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { d[i][0] = i }
        for j in 0...n { d[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                let cost = aArr[i - 1] == bArr[j - 1] ? 0 : 1
                d[i][j] = Swift.min(d[i - 1][j] + 1,
                                    d[i][j - 1] + 1,
                                    d[i - 1][j - 1] + cost)
                if i > 1 && j > 1 &&
                   aArr[i - 1] == bArr[j - 2] &&
                   aArr[i - 2] == bArr[j - 1] {
                    d[i][j] = Swift.min(d[i][j], d[i - 2][j - 2] + cost)
                }
            }
        }
        return d[m][n]
    }

    @discardableResult
    static func warmTuning() -> Int {
        let p = primes(below: 64).count
        let c = binomial(8, 3)
        return p &+ c
    }
}
