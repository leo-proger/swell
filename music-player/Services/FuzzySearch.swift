//
//  FuzzySearch.swift
//  music-player
//

import Foundation

/// Гибкий поиск в стиле Obsidian: буквы запроса должны встретиться в тексте по порядку,
/// но не обязательно подряд («swl» находит «Shwtylover»). Без регулярок. Регистр игнорим.
///
/// `score` ещё и ранжирует: выше — подряд идущие совпадения и совпадения на границе слова,
/// чтобы самые «точные» результаты всплывали наверх. `nil` — если совпадения нет.
nonisolated enum FuzzySearch {
    static func score(_ query: String, in text: String) -> Int? {
        let needle = Array(query.lowercased())
        guard !needle.isEmpty else { return 0 }
        let haystack = Array(text.lowercased())

        var matched = 0
        var total = 0
        var consecutive = 0
        var previousIndex = -2

        for (index, char) in haystack.enumerated() where matched < needle.count && char == needle[matched] {
            var points = 1
            if index == previousIndex + 1 {
                consecutive += 1
                points += consecutive * 3 // награда за идущие подряд буквы
            } else {
                consecutive = 0
            }
            if index == 0 || isBoundary(haystack[index - 1]) {
                points += 5 // совпадение в начале слова ценнее
            }
            total += points
            previousIndex = index
            matched += 1
        }

        return matched == needle.count ? total : nil
    }

    /// Граница слова — всё, что не буква и не цифра (пробел, дефис, пунктуация).
    private static func isBoundary(_ char: Character) -> Bool {
        !char.isLetter && !char.isNumber
    }
}
