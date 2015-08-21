---
title: 'FAQ'
layout: default
---

# FAQ


## Capabilities

#### How do I do a backgrounded multipart request that switches to streaming while pulling a double shot of espresso?

Find a lower-level networking library. And a barista.

Siesta is a high-level library designed to make the common behaviors of REST APIs simple to use. It’s an awesome way to manage your workaday REST calls, but it’s not a networking Swiss army knife.

#### What if I’m downloading huge responses, and I don’t want them held in memory all at once?

Use a lower-level networking library.

If you aren’t interested in holding a response entirely in memory, there’s little benefit to using Siesta. Siesta’s advantage over lower-level networking is the “parse once, share everywhere” nature of its observer architecture — which implies holding on to entire responses for reuse.
