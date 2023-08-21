# Stage based messaging
Stage based messaging uses the additional features of ContentRepo's ordered content sets, where you can set a contact field, and a relative time, for each content page in the set.

These flows will then take that ordered content set, and send those pages to the user using the schedule provided.

The way it works is, it schedules one message at a time. So after sign up the next message is scheduled. Then after that message is sent, the following message is scheduled.

It uses 2 contact fields: `push_messaging_content_set`, which stores the ID of the content set that the user signed up for, and `push_messaging_content_set_position`, which stores which message in the message set the user should receive next.

It also sets the `push_messaging_signup` to the timestamp when the user signed up to the messaging, so that you can use that in the ordered content set to schedule messages relative to signup