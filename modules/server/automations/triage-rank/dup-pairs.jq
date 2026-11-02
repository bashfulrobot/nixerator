# Possible duplicate pairs for the triage-rank report (claudoist issue 22).
# Input: the ranked tasks, each with id and title (titles are already cleaned).
# Output: [{a, b, score}], best score first, at most 50, over at most 100 tasks.
#
# Two tasks are a pair when their titles share at least 80% of their words
# (Jaccard on the sets of words). A word is a run of letters or digits that is 3
# characters or longer, or that holds a digit or a non-ASCII letter (short CJK words count), so "Q3" and "12" count and
# "Pay invoice 12" never pairs with "Pay invoice 15". Each title needs at least 2
# words. Letters of any script are kept; only ASCII letters are lowercased, so
# "Reunion" and "REUNION" match and "Réunion" matches itself.
# The model plays no part. Nothing merges or edits a task.
def toks:
  ascii_downcase
  | gsub("[^\\p{L}\\p{M}\\p{N}]+"; " ")
  | split(" ")
  | map(select(length > 2 or test("[0-9]") or test("[^\\x00-\\x7f]")))
  | unique;

.[0:100]
| map({id, t: (.title | toks)}) as $x
| [ range(0; $x | length) as $i | range($i + 1; $x | length) as $j
    | $x[$i] as $a | $x[$j] as $b
    | select(($a.t | length) >= 2 and ($b.t | length) >= 2)
    | (($a.t - ($a.t - $b.t)) | length) as $inter
    | (($a.t + $b.t) | unique | length) as $uni
    | select($inter / $uni >= 0.8)
    | {a: $a.id, b: $b.id, score: ((($inter / $uni) * 100 | floor) / 100)} ]
| sort_by(-.score)
| .[0:50]
