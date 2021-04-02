/**
 *
 * \section COPYRIGHT
 *
 * Copyright 2013-2021 Software Radio Systems Limited
 *
 * By using this file, you agree to the terms and conditions set
 * forth in the LICENSE file which can be found at the top level of
 * the distribution.
 *
 */

#ifndef SRSRAN_TYPE_STORAGE_H
#define SRSRAN_TYPE_STORAGE_H

#include <cstddef>
#include <cstdint>
#include <type_traits>
#include <utility>

namespace srsran {

namespace detail {

// NOTE: gcc 4.8.5 is missing std::max_align_t. Need to create a struct
union max_alignment_t {
  char        c;
  float       f;
  uint32_t    i;
  uint64_t    i2;
  double      d;
  long double d2;
  uint32_t*   ptr;
};

template <typename T, size_t MinSize = 0, size_t AlignSize = 0>
struct type_storage {
  using value_type = T;

  template <typename... Args>
  void emplace(Args&&... args)
  {
    new (&buffer) T(std::forward<Args>(args)...);
  }
  void destroy() { get().~T(); }
  void copy_ctor(const type_storage& other) { emplace(other.get()); }
  void move_ctor(type_storage&& other) { emplace(std::move(other.get())); }
  void copy_assign(const type_storage& other) { get() = other.get(); }
  void move_assign(type_storage&& other) { get() = std::move(other.get()); }

  T&       get() { return reinterpret_cast<T&>(buffer); }
  const T& get() const { return reinterpret_cast<const T&>(buffer); }

  void*       addr() { return static_cast<void*>(&buffer); }
  const void* addr() const { return static_cast<void*>(&buffer); }
  explicit    operator void*() { return addr(); }

  const static size_t obj_size   = sizeof(T) > MinSize ? sizeof(T) : MinSize;
  const static size_t align_size = alignof(T) > AlignSize ? alignof(T) : AlignSize;

  typename std::aligned_storage<obj_size, align_size>::type buffer;
};

template <typename T, size_t MinSize, size_t AlignSize>
void copy_if_present_helper(type_storage<T, MinSize, AlignSize>&       lhs,
                            const type_storage<T, MinSize, AlignSize>& rhs,
                            bool                                       lhs_present,
                            bool                                       rhs_present)
{
  if (lhs_present and rhs_present) {
    lhs.get() = rhs.get();
  }
  if (lhs_present) {
    lhs.destroy();
  }
  if (rhs_present) {
    lhs.copy_ctor(rhs);
  }
}

template <typename T, size_t MinSize, size_t AlignSize>
void move_if_present_helper(type_storage<T, MinSize, AlignSize>& lhs,
                            type_storage<T, MinSize, AlignSize>& rhs,
                            bool                                 lhs_present,
                            bool                                 rhs_present)
{
  if (lhs_present and rhs_present) {
    lhs.move_assign(std::move(rhs));
  }
  if (lhs_present) {
    lhs.destroy();
  }
  if (rhs_present) {
    lhs.move_ctor(std::move(rhs));
  }
}

} // namespace detail

} // namespace srsran

#endif // SRSRAN_TYPE_STORAGE_H
