# scryfallquery-moxfieldcsv

Retrieve a query to scryfall's URL api as a moxfield-format csv for bulk import. 

Good for building csvs for bulk import after a draft.

Workflow: key in collector numbers one per line

Find/replace to build a query that looks like the following for set number and all cards, for scryfall search. Test query in scryfall to check expected output.

s:ONE and (cn:001 or cn:002 or cn:003)

1. Download on linux/unix/macos
2. chmod +x mtg-scrygetter.sh
3. ./mtg-scrygetter.sh -q 'SCRYFALL SYNTAX QUERY HERE'

or ./mtg-scrygetter.sh to recieve a prompt for the query.
4. Specify output .csv. Confirm no collector numbers were missing (if bulk importing following a draft)
5. Bulk upload to a binder in moxfield

TO-DO: list unmatched cn, set pairs in seperate .csv. Some printings arent easily found in scryfall by cn search. Req's intelligently parsing scryfall queries to work across complicated queries. For the most part, if it works on the site it works though this api call
