# Checks the free-time file the claudoist helper writes on a laptop (claudoist
# issue 22, docs/phase5-spec.md) and returns a clean copy, or null when the file
# should not be used. Input: the parsed file. Arguments: $now, the current time
# as an ISO 8601 UTC string.
#
# The file is trusted only when it is version 1, written in the last 24 hours and
# not in the future (5 minutes of skew allowed), with well formed days and
# blocks. Anything else returns null, and the ranking runs as it did before.
# Every value that survives is re-built from strings and numbers this program
# checked, so nothing from the file reaches the prompt unchecked.
def ok_time: type == "string" and test("^([01][0-9]|2[0-3]):[0-5][0-9]$");
def ok_day: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
def written: sub("\\.[0-9]+Z$"; "Z") | try fromdateiso8601 catch null;

if (type == "object")
   and (.version == 1)
   and ((.written_at | type) == "string")
   and ((.work_hours | type) == "string") and (.work_hours | test("^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$"))
   and ((.days | type) == "array") and ((.days | length) <= 14)
then
  ($now | fromdateiso8601) as $n
  | (.written_at | written) as $w
  | if $w == null or ($n - $w) > 86400 or ($n - $w) < -300 then null
    elif ([.days[] | select((type == "object") and (.date | ok_day) and ((.blocks | type) == "array") and ((.blocks | length) <= 48)
            and ([.blocks[] | select((type == "object") and (.start | ok_time) and (.end | ok_time) and ((.minutes | type) == "number") and (.minutes >= 1) and (.minutes <= 1440))] | length) == (.blocks | length))] | length) != (.days | length)
    then null
    else {
      work_hours: .work_hours,
      days: [.days[] | {date, blocks: [.blocks[] | {start, end, minutes: (.minutes | floor)}]}]
    }
    end
else null end
