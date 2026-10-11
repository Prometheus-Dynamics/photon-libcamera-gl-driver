/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * Fallback for toolchains whose kernel UAPI headers predate Linux 5.6 (for
 * example Buildroot's Bootlin "stable" aarch64 toolchain, which ships 5.4
 * headers). Mirrors include/uapi/linux/dma-heap.h; CMake only adds this
 * directory when the toolchain lacks the real header. The DMA heap ioctl is
 * resolved against the running kernel, so this is safe on 5.6+ kernels.
 */
#ifndef _UAPI_LINUX_DMABUF_POOL_H
#define _UAPI_LINUX_DMABUF_POOL_H

#include <linux/ioctl.h>
#include <linux/types.h>

#define DMA_HEAP_VALID_FD_FLAGS (O_CLOEXEC | O_ACCMODE)
#define DMA_HEAP_VALID_HEAP_FLAGS (0ULL)

struct dma_heap_allocation_data {
    __u64 len;
    __u32 fd;
    __u32 fd_flags;
    __u64 heap_flags;
};

#define DMA_HEAP_IOC_MAGIC 'H'
#define DMA_HEAP_IOCTL_ALLOC                                                   \
    _IOWR(DMA_HEAP_IOC_MAGIC, 0x0, struct dma_heap_allocation_data)

#endif /* _UAPI_LINUX_DMABUF_POOL_H */
