This is a **Kubernetes (K3s) deployment architecture**. It shows how your Docker microservices project gets deployed into a Kubernetes cluster. Let me walk through every part:

---

## Top Left — Docker Hub

These are your 6 custom-built Docker images pushed to Docker Hub:

- `billing-app`
- `billing-database`
- `inventory-app`
- `inventory-database`
- `rabbitmq-server`
- `api-gateway`

Think of Docker Hub as your **image registry** — a remote storage where your built images live so Kubernetes can pull them down and run them.

---

## Top Right — Manifests

These are **YAML configuration files** that tell Kubernetes what to run and how:

- `rabbitmq.yaml`
- `billing-app.yaml`
- `inventory-app.yaml`
- `billing-database.yaml`
- `inventory-database.yaml`

In Docker Compose you had one `docker-compose.yml`. In Kubernetes, each service gets its own YAML manifest. These files describe things like how many replicas to run, what image to use, what ports to expose, what volumes to mount, and what secrets to inject.

---

## Right Side — The Toolchain

**VagrantFile → Vagrant → Kubectl**

This is the **infrastructure provisioning chain**:

- **VagrantFile** — a configuration file that defines a VM (like your VirtualBox Ubuntu VM). It describes the OS, memory, CPU, and network settings.
- **Vagrant** — reads the VagrantFile and automatically creates and configures the VM. Instead of manually setting up VirtualBox like you did, Vagrant automates it.
- **Kubectl** — the command line tool for talking to Kubernetes. The K3s Admin uses kubectl to apply the manifests, check pod status, scale services, and manage the cluster.

The flow is: VagrantFile defines the VM → Vagrant creates it → kubectl applies manifests to the K3s cluster running inside it.

---

## The K3s Cluster — The Main Box

**K3s** is a lightweight version of Kubernetes, designed to run on small VMs or edge devices. It's the same as full Kubernetes but stripped down to use less memory — perfect for a VirtualBox VM.

Inside the cluster you have several components:

---

### api-gateway (with multiple pods shown as `app`)

The green arrow from the **Client** goes directly into the **api-gateway**. This is the only entry point — exactly like port 3000 in your Docker Compose setup. In Kubernetes this is exposed via a **Service** (NodePort or LoadBalancer) so external traffic can reach it. The multiple `app` boxes inside it represent **replicas** — Kubernetes can run multiple copies of the same pod for high availability.

---

### rabbitmq (Queue)

Sits inside the cluster, connected to both api-gateway and billing-app. Same role as before — async message broker. The Queue icon shows the durable `billing_queue`. In Kubernetes this runs as a **StatefulSet** or **Deployment** with its credentials stored in Secrets.

---

### inventory-app (multiple pods)

Connected from api-gateway via HTTP proxy, just like before. The multiple `app` boxes again show Kubernetes can scale this horizontally — run 2, 3, or more replicas behind a single internal **Service** that load-balances between them.

---

### billing-app (single pod)

Consumes from RabbitMQ queue, writes to Billing Database. Shown with one replica here since it's a queue consumer.

---

### Inventory Database and Billing Database

These are **PostgreSQL instances** running as pods, connected to their respective **Volumes**. In Kubernetes, databases use **PersistentVolumeClaims (PVC)** — the Kubernetes equivalent of Docker named volumes. The data survives pod restarts because it's stored in the PersistentVolume, not in the container.

---

### Secrets

Bottom left of the cluster shows three secrets:

- **RabbitMQ Secrets** — username and password
- **Inventory Database Secrets** — DB credentials
- **Billing Database Secrets** — DB credentials

In Docker Compose you used a `.env` file. In Kubernetes, **Secrets** are the proper way to inject credentials — they're base64-encoded, stored in the cluster, and mounted into pods as environment variables. No credentials in YAML files.

---

### Volumes

Bottom right shows:

- **Billing Database Volume**
- **Inventory Database Volume**

These are **PersistentVolumes (PV)** — the Kubernetes equivalent of your Docker named volumes. They outlive pod restarts and store the actual PostgreSQL data files.

---

## The Full Flow Summary

```
VagrantFile → Vagrant creates VM
                    ↓
             K3s installs inside VM
                    ↓
K3s Admin applies YAML manifests via kubectl
                    ↓
K3s pulls images from Docker Hub
                    ↓
Pods start running inside the cluster
                    ↓
Client → api-gateway → inventory-app → inventory-database
                    ↓
         api-gateway → RabbitMQ queue → billing-app → billing-database
```

---

## Docker Compose vs This Architecture

| Concept       | Docker Compose       | Kubernetes (K3s)        |
| ------------- | -------------------- | ----------------------- |
| Config file   | `docker-compose.yml` | Multiple YAML manifests |
| Credentials   | `.env` file          | Secrets                 |
| Data storage  | Named volumes        | PersistentVolumes       |
| Scaling       | Manual               | Built-in replicas       |
| VM setup      | Manual VirtualBox    | Vagrant automated       |
| Orchestration | docker-compose       | kubectl + K3s           |

The core application logic is identical — you're just moving from Docker Compose to a production-grade Kubernetes orchestration layer.

//////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

---

## You Type a Website Address and Hit Enter

That's it. That's all you do. Everything else happens automatically, invisibly, in milliseconds. Let me show you what happens behind the scenes.

---

## Your Request Travels Through the Internet

When you hit enter, your request leaves your laptop and travels through the internet — through cables, routers, data centers — until it reaches **the virtual computer** running inside a server somewhere. In this case, that server is the VM that Vagrant built.

---

## It Hits the Only Open Door — api-gateway (Port 3000)

The virtual computer has thousands of ports — think of them like doors on a building. Almost all of them are locked. Only **one door is open — port 3000**. That's the api-gateway. Your request walks through that one door.

Everything else — the databases, the queue, the other apps — are locked rooms inside the building. No one from outside can reach them directly. Only the api-gateway can talk to them.

---

## The api-gateway Reads Your Request and Decides What to Do

The api-gateway is like a **receptionist**. It reads your request and decides where to send it. You don't choose — it decides based on what you asked for.

---

## Your Answer Comes Back

The right service processes your request, the data comes back through the api-gateway, and your browser displays it. From your perspective it felt instant.

---

## Now — What Is K3s Actually Doing During All of This?

This is the part most people never think about. While you're happily using the website, K3s is doing this **every single second**:

- Checking every app is still alive
- If something crashed — **automatically restarting it before you even notice**
- Making sure the right number of copies are running
- Making sure passwords are available to the apps that need them
- Making sure the data volumes are mounted and accessible

You never see any of this. The website just works.

---

## What Happens if Something Crashes While You're Using It?

Let's say the inventory-app crashes exactly when you click "show movies."

**Without K3s:** The app is dead. You get an error. Someone has to manually log in, find the problem, restart the app. Could take minutes or hours.

**With K3s:** K3s notices the crash in seconds, automatically starts a fresh copy, and by the time you refresh your browser — it's back. You might see one failed request. That's it.

---

## What Happens to Your Data if the Database Crashes?

The database pod crashes. K3s restarts it. But your data — all the movies, all the orders — is stored in the **Volume**, which is separate from the database pod itself. Think of it like this:

The database is a **DVD player**. The volume is the **DVD**. If the DVD player breaks, you get a new DVD player. The DVD — your data — is completely fine.

---

## The Full Journey of One Request — Plain English

```
You click "Show me all movies"
        ↓
Request leaves your browser
        ↓
Travels through the internet to the VM
        ↓
Enters through the only open door (api-gateway, port 3000)
        ↓
api-gateway sends it to inventory-app
        ↓
inventory-app asks the database "give me all movies"
        ↓
Database reads from the Volume (where data actually lives)
        ↓
Data travels back through inventory-app → api-gateway → internet → your browser
        ↓
You see the list of movies
```

**Total time: milliseconds. Your involvement: one click.**

---

## And the Whole Time, Behind the Scenes:

```
Vagrant created the computer once
        ↓
K3s was installed on it once
        ↓
Admin applied the YAML files once
        ↓
K3s pulled the apps from Docker Hub once
        ↓
Now K3s just watches forever
        ↓
Secrets keep passwords safe forever
        ↓
Volumes keep data safe forever
        ↓
You just use the website
        ↓
You never think about any of this
```

---

That's the entire point of this architecture. **You click. It works. Someone or something crashed somewhere. You never knew.**

When I say "app" in that context, I mean Pod.

Here's how the terms stack up, from bottom to top:
Docker Image
This is just a blueprint. A frozen snapshot of your application code. It does nothing on its own. It just sits in Docker Hub waiting to be used. Think of it like a recipe.
Container
When K3s takes that image and actually runs it, it becomes a container. The recipe is now actual food being cooked. But you rarely talk about containers directly in Kubernetes.
Pod
A Pod is the smallest running unit in Kubernetes. It wraps one or more containers and gives them an identity inside the cluster — a name, an IP address, resources. When K3s says "is this app alive?" it's checking the Pod.

So when I said:

"Checking every app is still alive" → K3s is pinging each Pod to see if it's responding
"Automatically restarting it" → K3s kills the broken Pod and creates a fresh one from the Docker Image
"Making sure the right number of copies are running" → K3s counts how many Pods of each type are running and matches what the YAML file said
"Passwords are available" → Secrets are injected into the Pod as environment variables when it starts
"Data volumes are mounted" → The Volume is attached to the Pod before it boots

=================================================================================

---

## Priority Order to Learn These

| Priority | Concept                   | Why                                |
| -------- | ------------------------- | ---------------------------------- |
| 1st      | Pod                       | Everything else builds on this     |
| 2nd      | Service                   | Nothing talks without this         |
| 3rd      | Deployment vs StatefulSet | Wrong choice breaks your data      |
| 4th      | PersistentVolume + PVC    | Databases need this                |
| 5th      | Secret                    | No credentials without this        |
| 6th      | Node token + kubeconfig   | Cluster won't connect without this |
| 7th      | HPA                       | Last thing to configure            |
| 8th      | kubectl commands          | Your daily tool                    |

---

## 1. What is a Node

A node is just a computer. In this project you have two:

- **Master node** — the brain. It makes all decisions. It knows what's running, what crashed, what needs to start.
- **Agent/Worker node** — the muscle. It just runs whatever the master tells it to run.

You must understand this relationship before anything else. The master never runs your apps itself — it only manages. The agent just executes.

---

## 2. What is a Pod

The smallest thing Kubernetes runs. One pod = one running instance of your app. Not the image, not the container — the **live running thing** inside the cluster.

When something crashes, Kubernetes doesn't fix it — it throws it away and creates a brand new Pod from the image. Like replacing a broken light bulb, not repairing it.

---

## 3. Deployment vs StatefulSet

This is critical for this project.

**Deployment** — for apps that don't care about their identity. You can kill any copy and replace it with a fresh one. Each copy is identical and replaceable. Used for api-gateway, inventory-app, rabbitmq.

**StatefulSet** — for apps that have memory, identity, or data. Each pod gets a stable name and its own dedicated storage. If pod-0 dies, the replacement is also named pod-0 and reconnects to the same data. Used for databases and billing-app.

Think of it this way — a Deployment is like a fast food worker, anyone can take the shift. A StatefulSet is like an assigned locker, only you get that locker number.

---

## 4. Service — How Pods Talk to Each Other

Pods get random IP addresses that change every time they restart. So you can never hardcode an IP. A **Service** sits in front of pods and gives them a stable name that never changes.

Three types you need to know:

- **ClusterIP** — only reachable inside the cluster. Used for databases, rabbitmq, internal apps.
- **NodePort** — opens a port on the actual VM so outside traffic can get in. Used for api-gateway.
- **Headless** — required for StatefulSets. No load balancing, pods are reached by name directly.

---

## 5. PersistentVolume and PersistentVolumeClaim

This is how data survives pod restarts in Kubernetes.

- **PersistentVolume (PV)** — the actual storage space that exists on the node. Like a hard drive plugged into the machine.
- **PersistentVolumeClaim (PVC)** — a pod's request for storage. "I need 1GB of storage." Kubernetes matches it to a PV.

StatefulSets create their own PVCs automatically using **volumeClaimTemplates**. You define the template once, each pod gets its own dedicated storage automatically.

---

## 6. Secret

The Kubernetes replacement for your `.env` file. Passwords are stored base64-encoded inside the cluster. Pods read them as environment variables at startup. The key rule — **passwords exist only in Secret manifests, nowhere else**.

---

## 7. HPA — Horizontal Pod Autoscaler

Watches CPU usage of a Deployment. When CPU goes above your threshold (60% in this project), it automatically creates more pods to share the load. When load drops, it removes them.

**Critical thing to know** — HPA is completely blind unless you define `resources.requests.cpu` in your Deployment. Without it, HPA has nothing to measure and does nothing silently.

---

## 8. kubectl

The command line tool you use from your iMac to control the entire cluster. You never SSH into the VM to manage Kubernetes — you run kubectl locally and it talks to the master node remotely.

The most important commands you'll use constantly:

```bash
kubectl get pods              # are my pods running?
kubectl get nodes             # are master and agent ready?
kubectl apply -f file.yaml    # deploy something
kubectl delete -f file.yaml   # remove something
kubectl logs pod-name         # see what an app is printing
kubectl describe pod pod-name # deep detail on why something failed
```

---

## 9. Vagrant and the VagrantFile

Vagrant automates VM creation. Instead of clicking through VirtualBox manually, you write a VagrantFile describing what you want — OS, RAM, CPU, network IP, what scripts to run on boot. Then one command creates everything.

The key thing to understand — `vagrant up` creates the VMs AND runs your provisioning scripts automatically. Your `master.sh` script installs K3s server. Your `agent.sh` script joins the cluster. This all happens automatically.

---

## 10. The Node Token — The Most Missed Concept

When the agent wants to join the master's cluster, it needs proof it's allowed to. The master generates a **node token** after K3s installs. The agent must present this token to join.

Your `master.sh` saves this token somewhere. Your `agent.sh` reads it and uses it. If this handshake fails, your agent never joins and you only have a single-node cluster.

---

## 11. kubeconfig — How kubectl Finds the Cluster

kubectl needs to know where the cluster is and how to authenticate. This lives in a file called `kubeconfig`, generated by K3s on the master at `/etc/rancher/k3s/k3s.yaml`. You copy this to your iMac and point kubectl at it. One gotcha — it says `127.0.0.1` inside the file, you must replace that with your master VM's actual IP (`192.168.56.10`) or kubectl can't reach it from outside the VM.

---

## The Mental Model Before You Start

```
Your iMac
    ↓ kubectl (sends instructions)
    ↓
Master VM (K3s brain)
    ↓ tells agent what to run
    ↓
Agent VM (K3s muscle)
    ↓ pulls images from Docker Hub
    ↓ runs Pods
    ↓ stores data in PersistentVolumes
    ↓ reads passwords from Secrets
    ↓ exposes api-gateway via NodePort
    ↓
User hits api-gateway → everything works
```

---

---

## Pods Running on Worker Node

| Component          | Pods                                       | Type        |
| ------------------ | ------------------------------------------ | ----------- |
| api-gateway        | 3 pods (shown as app, app, app with `...`) | Deployment  |
| inventory-app      | 3 pods (shown as app, app, app with `...`) | Deployment  |
| billing-app        | 1 pod                                      | StatefulSet |
| rabbitmq           | 1 pod                                      | Deployment  |
| inventory-database | 1 pod                                      | StatefulSet |
| billing-database   | 1 pod                                      | StatefulSet |

---

## Total = minimum 10 pods

But the `...` on api-gateway and inventory-app means **these can scale up automatically via HPA**. The `...` is showing that more pods can be added when CPU hits 60%.

---

## The ones with fixed 1 pod

- **billing-app** — 1 fixed, no scaling
- **rabbitmq** — 1 fixed, no scaling
- **inventory-database** — 1 fixed, no scaling
- **billing-database** — 1 fixed, no scaling

These never scale because databases and queue consumers need stable identity, not multiple copies.

---

Controller Manager

The kube-controller-manager runs many controllers such as:

Deployment Controller → ensures desired ReplicaSets/Pods exist
ReplicaSet Controller → ensures correct number of Pods
StatefulSet Controller → maintains ordered Pods
Node Controller → monitors nodes
Job Controller → ensures jobs complete
