# Browsable FAQs with media support
This provides an interface to the user to be able to browse through the tree-structured content in the ContentRepo.

It starts by allowing the user to select from the index pages.

They can then select through the tree structure, until they reach a leaf, at which point they're shown the WhatsApp content.

They can then go through all the WhatsApp messages on that content page (if there are multiple messages for the content page)

On the last message of the page, if there are related pages for that content page, they are given the option to navigate to one of those. Otherwise they are given the option to navigate to the main menu.

If the page has one media, the media will be displayed and followed by the main menu. 

if the page have more than one media e.g image and a video they will be given a button option to select which media they would like to view followed by the main menu.

# Editing flows
This flow is stored in the `platform-1` sandbox number on the `Praekelt.org` organisation on the whatsapp.turn.io instance.

It is synced and managed by the (flow-wrangler)[https://github.com/praekeltfoundation/flow-wrangler]