---
layout: post
title: Analysis of Mitosis
date: 2020-02-17
categories: [Paper]
tags: []
link: http://www.cs.yale.edu/homes/abhishek/jgandhi-asplos20.pdf
last_modified_at: 2020-02-17
---

### Problem
data placement 에 관한 연구가 많았지만 그에 비해 page table 에 관한 연구가 부족했다. "data placement 를 잘하면 어플리케이션 성능이 좋아진다." 라는 것은 이미 알려져있다. 그러나 데이터의 크기가 증가하면 그에 따라 TLB miss 에 의한 성능 저하도 같이 심각해지게 된다. 이러한 문제점들을 지적하며 이 논문에서는 총 네 가지의 contribution 을 언급한다.

__Contributions__  
1. page table placement 가 야기할 수 있는 문제점들을 실제 실험을 통해 검증하였다.
    * page-table walking 을 하게 되면 상황에 따라 여러 번의 remote 메모리 접근을 할 수 있다.
    * Figure 1 의 왼쪽 상단 테이블을 보면 많은 양의 PTE 들이 remote 에 분포되어있는 것을 확인할 수 있다.
    * OS 에선 여러 가지 이유로 workload 를 다른 소켓에 migration 하는 경우가 있는데 이 때 데이터만 옮길뿐 page table 은 옮기지 않는다. 이는 TLB miss 발생시 remote access 야기하고 Figure 1 오른쪽 그래프처럼 GUPS 성능에 많은 악영향을 끼친다.
2. replication / migration 기술들을 사용하여 성능을 향상 시켰다.
3. x86/64 Linux kernel 에서 개발되었으며 PVOps interface 를 사용하여 user-level library 도 개발하였다.
4. _Mitosis_ 기반의 시스템에서 측정한 성능 / 성능 환경에 관한 자세한 내용을 설명하였다.

### Background
* 메모리 텐시브 워크로드들이 보통 TLB miss 를 많이 발생시키는데 기존에 여러 가지 기술들이 TLB miss 에 따른 성능 저하를 줄이려 노력하였다. 예를 들어...
    * Reducing the frequency of TLB misses
    * Accelerating page-table walks
    * prefetching translations
    * TLB speculation
    * Eliminating or devirtualizing virtual memory
* page-table replication 은 data page migration 과 다르게 bytewise? copy 가 아니며 여러 level 을 고려해야하기 떄문에 단순한 copy 가 아니다.

### Page-Table Placement Analysis
__Multi-Socket Scenario__
* 전 노드 (4개) 에 스레드가 있는 상황에서 데이터는 로컬에 있고 각 레벨별로 다른 노드에 페이지 테이블들이 있는 경우 TLB miss 시 최대 4번의 remote access 가 발생한다.
* 프로세스의 페이지 테이블이 어떤 소켓에 위치하는지 알려주는 덤핑 모듈 및 CLI 을 만들어 워크로드가 실행되는동안 30초마다 호출한다.
* MMU cache 가 upper-level PTE 를 caching 하므로 performance 에 크게 영향을 주는 leaf-PTE 를 측정하였다
* Figure 3. 각 셀 맨 앞에 있는 숫자는 physical page 의 갯수이고 사각괄호 안에 있는 숫자들은 각 소켓별로 지정된 page-table pointer 들이다.
    * Socket 1: L4 - 1 [ 8 3 0 1 ] 의 의미는 L4 에 physical page 1개가 있고 socket 0 에 8개의 page-table pointer 가 있다는 뜻이다.
* page table 은 맨처음에 만들어진 자료구조때문에 나머지 남은 엔트리들의 주소 공간이 생성자의 소켓과 동일하고 이 때문에 만약 스레드가 다른 소켓에서 접근한다면 remote access 가 발생하게 된다.
* OpenMP 의 경우 싱글 스레드 allocation 이기 때문에 page table 이 한 쪽으로 쏠리는 경향이 있다.
* interleave 는 골고루 분산되기 때문에 pagetable 의 fraction 정도는 (N-1)/N 이다.
* Figure 4. remote leaf PTE 의 비율을 나타내며 적을수록 local에 page table 이 많이 할당되었다는 뜻이다. 반대로 비율이 높으면 그만큼 remote access 가 많이 발생한단 뜻이다.

__Workload Migration Scenario__  
* 이번엔 스레드가 load-balancing 등으로 migration 되었을때 page-table 이 다른 소켓에 있어 remote access 가 발생하는 경우다.
* allocation for data / page-table, socket idle or not, thp on/off, AutoNUMA off 과 같은 환경 구성을 하여 성능비교를 하였다.
* perf 를 사용하였으며 다음과 같은 event 들을 측정하였다. (Total execution cycle, load/store TLB miss)
* Figure 6. LP-LD 가 가장 좋으며 LP-RD/LP-RDI/RP-LD/RPI-LD 모두 안 좋은 성능이 측정되었다. 그리고 Data / pagetable 모두 remote 일 경우 가장 안 좋은 성능(x3.6)을 보였다.

### Mitosis
__Goals__  
* a mechanism to support low-overhead replication and Migration
* a policy for replication and migration

__Replication__  
* page table replication 을 통해 remote access 를 local access 로 바꿔줌
__Migration__  
* Load-balancing 에 의해 스레드가 migration 될 때 page table 도 같이 하여 remote access 를 없앰

### Implementation


### Evauation

### Reference
* [Paper](http://www.cs.yale.edu/homes/abhishek/jgandhi-asplos20.pdf)
* [GitHub](https://github.com/mitosis-project/mitosis-asplos20-artifact)
