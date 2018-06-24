---
layout: post
title:  "Packet reception"
date:   2018-05-15 21:07:38 +0900
categories: linux network
---

__Description__

외부에서 보내진 packet 을 NIC 로 받아서 main memory 로 올려지기까지 일련의 과정을 담은 글

### Initialization
{% highlight c %}
static int e1000_probe(struct pci_dev *pdev, const struct pci_device_id *ent)
{
   ...
   err = e1000_sw_init(adapter);
   ...
   /* construct the net_device struct */
   netif_napi_add(netdev, &adapter->napi, e1000e_poll, 64);
   ...

}
static int e1000_sw_init(struct e1000_adapter *adapter)
{
   ...
   adapter->rx_buffer_len = VLAN_ETH_FRAME_LEN + ETH_FCS_LEN;
   adapter->rx_ps_bsize0 = 128;
   adapater->rx_ring_count = E1000_DEFAULT_RXD;

   if (e1000_alloc_queues(adapter))
       return -ENOMEM;
   ...

}
static int e1000_alloc_queues(struct e1000_adapter *adapter)
{
    ...
    adapter->rx_ring = kzalloc(size, GFP_KERNEL);
    adapter->rx_ring->count = adapter->rx_ring_count;
    adapter->rx_ring->adapter = adapter;
    ...
}
{% endhighlight %}

{% highlight c %}
int e1000e_open(struct net_device *netdev)
{
    ...
    err = e1000e_setup_rx_resources(adapter->rx_ring);
    ...
    e1000_configure(adapter);
    ...
    napi_enable(&adapter->napi);
    e1000_irq_enable(adapter);
    ...
}
// referenced by e1000e_open
int e1000e_setup_rx_resources(struct e1000_ring *rx_ring)
{
    ...
    /* Round up to nearest 4K */
    rx_ring->size = ALIGN(rx_ring->size, 4096);
    err = e1000_alloc_ring_dma(adapter, rx_ring);
    ...
}
// referenced by e1000e_open
static void e1000_configure(struct e1000_adapter *adapter)
{
    ...
    e1000_configure_rx(adapter);
    adapter->alloc_rx_buf(rx_ring, e1000_desc_unused(rx_ring), GFP_KERNEL);
}
static void e1000_configure_rx(struct e1000_adapter *adapter)
{
    ...
    /* General case */
    rdlen = rx_ring->count * sizeof(union e1000_rx_desc_extended);
    adapter->clean_rx = e1000_clean_rx_irq;
    adapter->alloc_rx_buf = e1000_alloc_rx_buffers;
    ...
}
{% endhighlight %}

### Bottom Halves
{% highlight c %}
static bool e1000_clean_rx_irq(struct e1000_ring *rx_ring, int *work_done,
                    int work_to_do)
{
    ...
    e1000_receive_skb(adapter, netdev, skb, staterr, rx_desc->wb.upper.vlan);
    ...
    if (cleaned_count >= E1000_RX_BUFFER_WRITE) {
        adapter->alloc_rx_buf(rx_ring, cleaned_count, GFP_ATOMIC);
        cleaned_count = 0;
    }
    ...
}

// adapter->alloc_rx_buf
static void e1000_alloc_rx_buffers(struct e1000_ring *rx_ring,
                    int cleaned_count, gfp_t gfp)
{
    ...
    skb = __netdev_alloc_skb_ip_align(netdev, bufsz, gfp);
    ...
    buffer_info->dma = dma_map_single(&pdev->dev, skb->data,
                        adapter->rx_buffer_len,
                        DM_FROM_DEVICE);
    ...
}
{% endhighlight %}

#### Version
* linux-4.16.2

#### Reference
* [Understanding linux network internals](https://www.amazon.com/Understanding-Linux-Network-Internals-Networking/dp/0596002556) 
* [Linux device drivers](https://www.amazon.com/Linux-Device-Drivers-Jonathan-Corbet/dp/0596005903/ref=sr_1_2?s=books&ie=UTF8&qid=1526392385&sr=1-2&keywords=linux+device+drivers)
* [Linux kernel development](https://www.amazon.com/Linux-Kernel-Development-Robert-Love/dp/0672329468)

