---
layout: post
title: Analysis of Carrefour
date: 2020-02-09 12:30:45
categories: [Paper]
tags: []
link: http://www.fabiengaud.net/resources/dashti13traffic.pdf
last_modified_at: 2020-02-11
---

### Problem
* thread 가 local memory access 하는 것보다 remote memory access 하는 경우 성능이 더 안 좋다 - **Figure 2(a)**
* NAS workload 는 First-touch policy 가 좋고 steamcluster / PCA 는 Interleave 가 좋다 - **Figure 2(b)**
* Streamcluster / PCA 에서 First-toch 의 locality access ratio 가 best 인 interleave 와 크게 다르지 않다. 결국 성능 차이의 요인은 locality 가 아닌 memory latency 이며 latency 는 memory / IC imbalance 에서 비롯된다는 사실을 알 수 있다 - **Table 1**

*Figure 2(a) - wire delay 가 performance bottleneck 인 application 을 찾기 위해 thread 를 하나 사용하여 그 중에서 CPU Utlization 이 30% 이하인 것들은 제외함.*


### Design

#### Mechanisms
**Page co-location**  
싱글 스레드 혹은 멀티 스레드가 접근한 페이지를 접근한 스레드의 노드로 가져오는 방식

**Page interleaving**  
메모리 / 인터커넥트 링크의 트래픽이 불균형할 경우 페이지를 여러 노드로 분산시키는 방식

**Page replication**  
페이지 복사본을 다른 노드에 배치하는 방식. 좋은 성능을 기대할 수 있지만 반대로 많은 메모리 소모와 cache coherence protocol 에 따른 데이터 동기화를 해야하기 때문에 악영향을 끼칠 수 있다.

#### Algorithm
**Measurement**  
Global / Per-application 은 Hardware counter 로 측정하며 Per-page 데이터는 Instruction-based sampling(IBS) 로 측정한다

**Global Decisions**  
Global decision 은 시스템 와이드 트래픽과 워크로드의 특성에 따라 결정되고 총 4단계로 순차적으로 작동한다.

1. 실질적으로 메모리 사용량이 증가하는 시점에 *Carrefour* 를 작동시킬지에 대한 여부를 판단한다. 논문에선 50 `MAPTU`(Memory accesses per microsecond) 로 정했으며 시스템에 따라 유동적으로 설정 가능하다.
2. replication 을 해야하는 경우인지 판단한다. 논문에선 1 - (1/`NUM_NODES`) 만큼 가용 메모리 공간이 있고 `MRR`(Memory Read Ratio) 가 99% 이상인 워크로드에선 replication 이 설정된다.
3. `MC-IMB`(Memory Controller Imbalance) 가 35% 이상이면 인터리브가 설정된다.
4. Co-location 은 특정 페이지들이 하나의 노드에서만 접근되었을때 설정되며 `LAR`(Local Access Ratio) 이 80% 이하면 설정된다.

**Page-local Decisions**  
Global decisions 에서 시스템 관점에서 어떤 방식을 채택해야하는지 판단하였다면 이 단계에선 페이지 관점에서 어떠한 방식으로 채택된 메카니즘이 작동되는지에 대한 설명한다.

* 만약 페이지가 하나의 노드에서만 접근되었다면 그 노드로 마이그레이션된다.
* 만약 페이지가 여러 노드로부터 접근되었다면 interleave / replication 대상이 되고 이 페이지가 read-only 일 경우 남은 메모리 공간을 고려하여 replication 한다. 그렇지 않을 경우 interleave 마킹을 한다.
* 각 노드의 MAPTU (P_{migrate})를 계산하고 MAPTU 의 complement 값인 P_{node} 를 계산하여 P_{node} 가장 높은 곳으로 마이그레이션 한다. P_{node} 값이 높다는 것은 해당 노드의 로드가 적음을 의미한다.

### Implementation
#### Fast and accurate memory access sampling
* AMD 에서 제공하는 Instruction-Based Sampling(IBS)를 사용하며 인텔에서 비슷하게 PEBS(Precise Event-Based Sampling) 이라고 있다.
* IBS 는 샘플을 얻을 때마다 인터럽트를 발생시키기 때문에 이 오버헤드를 줄이기 위해 논문에선 adaptive sampling 을 사용하였다. 처음 프로그램이 시작되면 65,000 cycle 에 한 번씩 샘플링을 하다가 이 샘플링을 10번 정도 한 후 에는 260,000 cycle 에 한 번씩 샘플링을 한다. 만약 시스템 상황에 의해 샘플링 오버헤드가 있다고 판단되는 경우 횟수를 줄여서 1/260,000 cycle 샘플링이 실행되도록 한다.
* L1 cache 에 prefetching 되는 경우 메모리에 많은 접근을 하지 않으므로 이러한 데이터도 수집하여 page replication 을 작동시킨다.

#### Replication
replication 은 총 세 가지의 오버헤드가 있다. 첫 번째 오버헤드는 각 노드에 페이지를 생성해야하므로 이 과정에서 발생하는 시스템 리소스 소모다. 두 번째 오버헤드는 메모리 용량을 초과하였을때 커널이 처리해야할 프로세스에 대한 오버헤드다.
마지막으로 각 노드의 복사된 페이지들을 동기화 하는데 발생하는 오버헤드가 있다. 페이지의 동기화란 한 노드의 페이지에 write 가 발생하면 locking-protocol 를 사용해 전 노드의 복사본들의 데이터를 동기화하는 것을 뜻한다. 이것을 논문에선 page collapse 라고 부르며 많은 비용을 소모한다.

리눅스에선 process address space 를 `mm_struct` 로 표현하며 이 자료구조는 page table 의 포인터를 가진다. 이 page table 에는 page table entry(PTE) 라는 것이 있고 이 데이터를 값을 변경하게되면 lock 이 걸린다. *Carrefour* 에선 이 locking 을 사용하여 write 가 발생한 PTE 를 제외한 다른 복사본들에 read-protect 를 설정하고 write 가 끝나면 데이터를 업데이트 하는 방식으로 페이지 동기화를 구현하였다.

### Evauation
**비교대상**
* Linux v3.6: a standard Linux kernel with default first-touch memory allocation policy
* Manual Interleaving: a standard Linux kernel with interleaving policy
* AutoNUMA v27
* Carrefour

**Workload**
* NAS
* PARSEC v2.1
* map/reduce Metis suites

**Testbed**
* Machine A - 4 cores x 4 nodes = 16 cores
* Machine B - 6 cores x 4 nodes = 24 cores

#### Single-application workloads

#### Multi-application workloads

### Reference
* [Paper](http://www.fabiengaud.net/resources/dashti13traffic.pdf)
* [GitHub](https://github.com/Carrefour/carrefour-module)
