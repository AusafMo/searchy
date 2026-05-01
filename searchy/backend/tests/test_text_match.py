"""Tests for BM25 text scoring (replaced naive word overlap)."""

import math
from collections import Counter


# ── Standalone BM25 implementation for testing without heavy deps ──

BM25_K1 = 1.2
BM25_B = 0.75


def _tokenize(text):
    return text.lower().split()


def bm25_score(query, document, avg_doc_len, doc_count, doc_freq):
    if not query or not document:
        return 0.0

    query_terms = _tokenize(query)
    doc_terms = _tokenize(document)
    doc_len = len(doc_terms)

    if doc_len == 0 or avg_doc_len == 0:
        return 0.0

    tf_map = Counter(doc_terms)
    score = 0.0

    for term in query_terms:
        tf = tf_map.get(term, 0)
        if tf == 0:
            continue
        df = doc_freq.get(term, 0)
        idf = math.log((doc_count - df + 0.5) / (df + 0.5) + 1.0)
        tf_norm = (tf * (BM25_K1 + 1)) / (tf + BM25_K1 * (1 - BM25_B + BM25_B * doc_len / avg_doc_len))
        score += idf * tf_norm

    return score


def _build_corpus_stats(documents):
    doc_freq = {}
    total_len = 0
    doc_count = 0
    for doc in documents:
        if not doc:
            continue
        terms = set(_tokenize(doc))
        for term in terms:
            doc_freq[term] = doc_freq.get(term, 0) + 1
        total_len += len(_tokenize(doc))
        doc_count += 1
    avg_doc_len = total_len / doc_count if doc_count > 0 else 1.0
    return avg_doc_len, max(doc_count, 1), doc_freq


# ── Helpers ──

def _score_single(query, document, corpus=None):
    """Score a single query-document pair with a small corpus for context."""
    if corpus is None:
        corpus = [document]
    avg_len, count, df = _build_corpus_stats(corpus)
    return bm25_score(query, document, avg_len, count, df)


# ── Tests ──

def test_exact_term_match():
    score = _score_single("invoice 2024", "Payment invoice 2024 received")
    assert score > 0


def test_case_insensitive():
    score = _score_single("HELLO", "hello world")
    assert score > 0


def test_partial_word_match():
    corpus = ["blue car on road", "red truck in field"]
    avg_len, count, df = _build_corpus_stats(corpus)
    score = bm25_score("red car", "blue car on road", avg_len, count, df)
    # Only "car" matches, so score should be positive but lower
    assert score > 0


def test_no_match():
    score = _score_single("sunset", "spreadsheet data")
    assert score == 0.0


def test_empty_query():
    assert _score_single("", "some text") == 0.0


def test_empty_document():
    assert _score_single("hello", "") == 0.0


def test_both_empty():
    assert _score_single("", "") == 0.0


def test_all_words_match_scores_higher():
    corpus = ["world hello foo bar", "world baz qux"]
    avg_len, count, df = _build_corpus_stats(corpus)
    full_match = bm25_score("hello world", "world hello foo bar", avg_len, count, df)
    partial_match = bm25_score("hello world", "world baz qux", avg_len, count, df)
    assert full_match > partial_match


def test_rare_term_gets_higher_idf():
    """A term that appears in fewer documents should contribute more (higher IDF)."""
    corpus = [
        "common word here",
        "common word there",
        "common word everywhere",
        "rare unique term here",
    ]
    avg_len, count, df = _build_corpus_stats(corpus)
    score_rare = bm25_score("unique", "rare unique term here", avg_len, count, df)
    score_common = bm25_score("common", "common word here", avg_len, count, df)
    # "unique" appears in 1 doc, "common" in 3 → rare term should score higher
    assert score_rare > score_common


def test_rrf_basic():
    """Test that RRF correctly fuses two ranked lists."""
    from collections import defaultdict

    def rrf(ranked_lists, k=60):
        scores = defaultdict(float)
        for rl in ranked_lists:
            for rank, idx in enumerate(rl):
                scores[idx] += 1.0 / (k + rank + 1)
        return sorted(scores.items(), key=lambda x: x[1], reverse=True)

    # Doc 0 is #1 in both lists → should be top
    list1 = [0, 1, 2, 3]
    list2 = [0, 2, 1, 3]
    fused = rrf([list1, list2])
    assert fused[0][0] == 0  # Doc 0 should be first
