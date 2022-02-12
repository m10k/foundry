# foundry - a distributed package build system

Foundry is a distributed package build system. It is made up from a number of workers,
called bots, each of which performs one step of the package build process. The bots
talk to each other asynchronously using pub-sub messaging, making foundry highly
scalable and fault-tolerant. Because of its message-based architecture, new bots can
be written and integrated into foundry within minutes.

## Architecture

Foundry consists of four bots that cooperate to build packages from a git repository
and place the resulting packages in a package repository. These are the four bots:

| Bot      | Performed task                              |
|----------|---------------------------------------------|
| watchbot | Watch git repositories for changes          |
| buildbot | Build Debian packages from a git repository |
| signbot  | Sign Debian packages                        |
| distbot  | Add signed packages to a Debian repository  |

The bots communicate via pub-sub messaging, publishing their results (if successful)
under the following topics.

| Topic   | Message type | Description                                                       |
|---------|--------------|-------------------------------------------------------------------|
| commits | commit       | A change was detected on a git repository                         |
| builds  | build        | A build has completed successfully                                |
| signs   | sign         | The packages from a build message have been successfully signed   |
| dists   | dist         | The packages from a sign message have been successfully published |

The following diagram gives an overview how the individual foundry components interact. For
understandability's sake each bot is shown only once, but the foundry architecture does not
impose a limit on the number of bots. The messaging system that foundry is based on (toolbox's
ipc module) performs automatic load-balancing, allowing bots to be added or removed on demand.

#### How to read the architecture diagram

```
 (   data store  )
 [    process    ]
 < pub-sub topic >

 Relationships are expressed by arrows pointing from the subject to the object.
 The relationship below means "AAA writes to BBB".

 AAA
  |
  | writes to
  v
 BBB
```

#### Architecture Diagram

```
( git repository )
        ^
        | watch for changes
        |
   [ watchbot ]
        |
        | announce commit
        v
   < commits >
        ^
        | watch for commits
        |
   [ buildbot ]
        |
        | announce successful build
        v
    < builds >
        ^
        | watch for builds
        |
   [ signbot ]
        |
        | announce signed packages
        v
    < signs >
        ^
        | watch for signed packages
        |
   [ distbot ] ---------------.
        |                     |
        | publish packages    | announce published packages
        v                     v
( Debian repository )      < dists >
```

### Proof of Concept: Foundry for toolbox

Foundry is used to automate the build process of toolbox packages. It detects when changes
have been pushed to the stable or unstable branches of any of the toolbox repositories, and
immediately builds, signs, and publishes the new packages. The diagram below shows how the
components relate to each other.

```
( https://github.com/m10k/toolbox )
     ^
     | watch stable and
     | unstable branches
     |
[ watchbot ]
     |
   .-'    ( https://github.com/m10k/toolbox-goodies )
   |           ^
   |           | watch stable and
   |           | unstable branches
   |           |
   |      [ watchbot ]
   |           |
   | .---------'    ( https://github.com/m10k/toolbox-linux )
   | |                   ^
   | |                   | watch stable and
   | |                   | unstable branches
   | |                   |
   | |              [ watchbot ]
   | |                   |
   | | .-----------------'    ( https://github.com/m10k/toolbox-restapis )
   | | |                           ^
   | | |                           | watch stable and
   | | |                           | unstable branches
   | | |                           |
   | | |                      [ watchbot ]
   | | |                           |
   | | | .-------------------------'
   | | | |
   | | | | announce commits
   | | | |
   v v v v
 < commits >
     ^ ^
     | | watch for commits
     | |
     | '-----------.
     |             |
[ buildbot ]  [ buildbot ]
     |             |
     | .-----------'
     | |
     | | announce successful builds
     v v
  < builds >
      ^
      | watch for builds
      |
 [ signbot ]
      |
      | announce successful signs
      v
  < signs >
      ^
      | watch for signs
      |
 [ distbot ] -----------------------------.
     | |                                  | announce published packages
     | '---------------------------.      v
     |                             |  < dists >
     |                             |
     | publish packages built      | publish packages built
     | from stable branches        | from unstable branches
     v                             v
( deb.m10k.eu stable )        ( deb.m10k.eu unstable )
```

### Installation

There are no packages for foundry yet, so installation is still a manual (but
straightforward) process. This section explains how to get started.


#### Dependencies

First of all, make sure you have [toolbox](https://github.com/m10k/toolbox) installed
and the user you're going to use for foundry is member of the *toolbox_ipc* group.
Next, create `/var/lib/foundry/contexts` exists and make sure your user can write to it.

    # mkdir -p /var/lib/foundry/contexts
    # chown -R <user>.<group> /var/lib/foundry
    # chmod -R 770 /var/lib/foundry


#### Getting the sources

Foundry needs to be installed from the sources, so first you have to clone the git
repository.

    $ git clone https://github.com/m10k/foundry

Then, change into the foundry directory.

    $ cd foundry

Foundry comes with a number of toolbox modules, so we need to make sure toolbox can load
them.

    $ ln -s "$PWD/include" "$HOME/.toolbox/include/foundry"


### Starting foundry

Now we can start the build system.


#### Starting watchbot

First, we will start a watchbot to watch the toolbox repository's stable branch. This
can be achieved with the following command.

    $ ./watchbot.sh --repository https://github.com/m10k/toolbox#stable \
                    --name "somename"

A single watchbot can watch an arbitrary number of repositories. If you want to watch more
than one repository, pass `--repository` multiple times, as shown below.

    $ ./watchbot.sh --repository https://github.com/m10k/toolbox#stable   \
                    --repository https://github.com/m10k/toolbox#unstable \
                    --name "somename"

The purpose of the `--name` parameter was to make it easier to distinguish between running
instances. It's not used at all, so you can pass anything you like. This parameter will be
removed soon.

Watchbot supports watching of remote repositories (via git's dumb and smart HTTP transports)
as well as local repositories.

#### Starting buildbot

This one is really simple.

    $ ./buildbot.sh

By default, buildbot will use the IPC endpoint `pub/buildbot` to subscribe to *commits*.
This means, by default build jobs will be balanced over all buildbots. If you would prefer
multiple buildbots to build *the same* job in parallel, for example because you are
building for multiple architectures, you need to pass the `--endpoint` parameter. You can
think of the IPC endpoint as a load-balancing group. For example, consider you have started
four buildbots as shown below.

    $ ./buildbot.sh --endpoint pub/buildbot_i386
    $ ./buildbot.sh --endpoint pub/buildbot_i386
    $ ./buildbot.sh --endpoint pub/buildbot_amd64
    $ ./buildbot.sh --endpoint pub/buildbot_amd64

In this scenario, if a new commit is published, it is sent to either IPC endpoint. This
means, one of the buildbots listening on *pub/buildbot_i386* and one of the buildbots
listening on *pub/buildbot_amd64* will see the message.

#### Starting signbot

Signbots are started as shown below.

    $ ./signbot.sh --gpg-key <keyid>

The purpose of signbot is to sign Debian packages, so you need to tell it which key to
use using the `--gpg-key` option. The key must be a key-id from the default GPG key ring.
By default, signbots are load-balanced the same way as the buildbots. If you want to sign
packages going to one repository with a different key than packages going to a different
repository, you will have to start two signbots with differing `--endpoint` and
`--publish-to` options.

#### Starting distbot

Distbot has a few more options, but most of them are fairly self-explanatory.

    $ ./distbot.sh --name deb.example.org        \
                   --output /srv/www/deb         \
                   --arch amd64,i386             \
                   --gpg-key <keyid>              \
                   --description "My repository"

Like signbot, distbot needs a GPG key id. Unlike the signbot key, which is used to sign
packages, this key is used to sign the metadata in the repository. You are strongly
encouraged *not* to use the same key for both. If the path passed via `--output`
contains an existing repository, distbot will reuse it. Otherwise, it will create a new
repository in that path.

**Note:** If you have multiple signbots publishing messages to more than one topic, you
can change the topic that a distbot watches by passing `--watch` and the name of the
topic that your signbot is publishing messages on.


### Herding the bots

If you want to see a list of the running bots, pass `--list` to the bot you're interested
in. For example, the following command will list all running watchbots.

    $ ./watchbot.sh --list

If you want to stop a particular bot, use `--stop`.

    $ ./watchbot.sh --stop 12345

That's all you need to know to get started. If everything went well, you should be seeing
built packages in your Debian repository. If not, the logs within `$HOME/.toolbox/log`
might tell you what's going on. This is also a good opportunity to mention that you can
tell each of the bots to be more talkative by passing `--verbose` one or more times.
