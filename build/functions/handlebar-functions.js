// A Handlebars Helper to allow bespoke date formatting
// Azure DevOps returns dates in the format "Mon Aug 09 2021 08:31:02 GMT+0000 (Coordinated Universal Time)"
// This functions swaps them to a local format e.g."August 09, 2021 - 08:31"
/* Usage
    {{date_formatter_iso buildDetails.startTime}
    {{jira_url (get_only_message_firstline this.message) }}
*/

module.exports = {
    date_formatter_iso(theDate) {
        return theDate.toISOString();
    },
    jira_url(text) {
        const regex = /([A-Z][A-Z0-9]{1,9}-[1-9][0-9]*)/gm;
        const replaceUrl = "[$1](https://ezcorp.atlassian.net/browse/$1)"
        return text.replace(regex, replaceUrl);
    }
};
