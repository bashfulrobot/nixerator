# Checks the free-time file the claudoist helper writes on a laptop (claudoist
# issue 22, docs/phase5-spec.md) and returns a clean copy, or null when the file
# should not be used. Input: the parsed file. Arguments: $now, the current time
# as an ISO 8601 UTC string. With --arg why 1 the program returns the reason the
# file was refused instead (stale, future, version, malformed), or "ok". The
# reason is one of those fixed words, never text from the file.
#
# The file is trusted only when it is version 1, written in the last 24 hours and
# not in the future (5 minutes of skew allowed), with at most 14 days of at most
# 48 blocks. A day is a real calendar date, listed once. A block starts and ends
# on HH:MM, ends after it starts, and has 1 to 1440 minutes. Anything else
# returns null, and the ranking runs as it did before. Every value that survives
# is re-built from strings and numbers this program checked, so nothing from the
# file reaches the prompt unchecked. timezone is informational and kept only
# when it looks like a plain zone name, else it is null. utc_offset_seconds is
# the laptop's offset from UTC, kept only as an integer within 14 hours either
# way, else null. The ranking script uses the offset, never the name, to find
# the laptop's date.
def ok_time: type == "string" and test("^([01][0-9]|2[0-3]):[0-5][0-9]$");
def ok_day: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  and ((try (. + "T00:00:00Z" | fromdateiso8601 | todate[0:10]) catch null) == .);
def ok_block: (type == "object") and (.start | ok_time) and (.end | ok_time) and (.end > .start)
  and ((.minutes | type) == "number") and (.minutes >= 1) and (.minutes <= 1440);
def ok_day_entry: (type == "object") and (.date | ok_day) and ((.blocks | type) == "array")
  and ((.blocks | length) <= 48) and ([.blocks[] | select(ok_block)] | length) == (.blocks | length);
def written: sub("\\.[0-9]+Z$"; "Z") | try fromdateiso8601 catch null;

def verdict:
  if (type != "object") or ((.written_at | type) != "string") or ((.days | type) != "array") then {reason: "malformed"}
  elif .version != 1 then {reason: "version"}
  else
    (($now | fromdateiso8601)) as $n
    | (.written_at | written) as $w
    | if $w == null then {reason: "malformed"}
      elif ($n - $w) > 86400 then {reason: "stale"}
      elif ($n - $w) < -300 then {reason: "future"}
      elif ((.work_hours | type) != "string") or ((.work_hours | test("^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$")) | not) then {reason: "malformed"}
      elif (.days | length) > 14 then {reason: "malformed"}
      elif ([.days[] | select(ok_day_entry)] | length) != (.days | length) then {reason: "malformed"}
      elif ([.days[].date] | unique | length) != (.days | length) then {reason: "malformed"}
      else {reason: "ok", out: {
        work_hours: .work_hours,
        timezone: (if (.timezone | type) == "string" and (.timezone | test("^[A-Za-z0-9_+:/-]{1,40}$")) then .timezone else null end),
        utc_offset_seconds: (if (.utc_offset_seconds | type) == "number" and (.utc_offset_seconds == (.utc_offset_seconds | floor)) and (.utc_offset_seconds >= -50400) and (.utc_offset_seconds <= 50400) then .utc_offset_seconds else null end),
        days: [.days[] | {date, blocks: [.blocks[] | {start, end, minutes: (.minutes | floor)}]}]
      }}
      end
  end;

verdict | if ($ARGS.named.why // "") == "1" then .reason else (.out // null) end
