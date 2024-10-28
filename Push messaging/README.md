# Push Messaging
Push messaging uses the additional features of ContentRepo's ordered content sets, where you can set a contact field, and a relative time, for each content page in the set.

These flows will then take that ordered content set, and send those pages to the user using the schedule provided.

This works using Turn's triggers with a time relative to the contact field `push_messaging_signup`. Instead of explicitly keeping track of which message index we have / should send to the user, we calculate which message should be sent using `push_messaging_signup` as well. This means that when a message is added to or removed from CMS the recipient doesn't miss any messages, but it does mean that the journey has to be changed in lockstep by 
1. Adding the trigger for the new message 
1. Adding the relavent `DetermineMessage` card with correct conditions