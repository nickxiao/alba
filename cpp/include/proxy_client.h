/*
Copyright (C) 2016 iNuron NV

This file is part of Open vStorage Open Source Edition (OSE), as available from


    http://www.openvstorage.org and
    http://www.openvstorage.com.

This file is free software; you can redistribute it and/or modify it
under the terms of the GNU Affero General Public License v3 (GNU AGPLv3)
as published by the Free Software Foundation, in version 3 as it comes
in the <LICENSE.txt> file of the Open vStorage OSE distribution.

Open vStorage is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY of any kind.
*/

#ifndef ALBA_PROXY_CLIENT_H
#define ALBA_PROXY_CLIENT_H

#include <iosfwd>

#include <vector>
#include <boost/asio.hpp>
#include "proxy_protocol.h"
#include "boolean_enum.h"

namespace alba {
namespace proxy_client {

struct proxy_exception : std::exception {
  proxy_exception(uint32_t return_code, std::string what)
      : _return_code(return_code), _what(what) {}

  uint32_t _return_code;
  std::string _what;

  virtual const char *what() const noexcept { return _what.c_str(); }
};

BOOLEAN_ENUM(has_more)
BOOLEAN_ENUM(include_first)
BOOLEAN_ENUM(include_last)
BOOLEAN_ENUM(allow_overwrite)
BOOLEAN_ENUM(may_not_exist)
BOOLEAN_ENUM(reverse)
BOOLEAN_ENUM(consistent_read)
BOOLEAN_ENUM(should_cache)

class Proxy_client {
public:

  virtual std::tuple<std::vector<std::string>, has_more>
    list_namespaces(const std::string &first, const include_first,
                    const boost::optional<std::string> &last, const include_last,
                    const int max, const reverse reverse = reverse::F) = 0;

  virtual bool namespace_exists(const std::string &name) = 0;

  virtual void create_namespace(const std::string &name,
                                const boost::optional<std::string> &preset_name) = 0;

  virtual void delete_namespace(const std::string &name) = 0;

  virtual std::tuple<std::vector<std::string>, has_more>
    list_objects(const std::string &namespace_, const std::string &first,
                 const include_first, const boost::optional<std::string> &last,
                 const include_last, const int max,
                 const reverse reverse = reverse::F) = 0;

  virtual void read_object_fs(const std::string &namespace_,
                              const std::string &object_name,
                              const std::string &dest_file, const consistent_read,
                              const should_cache) = 0;

  virtual void write_object_fs(const std::string &namespace_,
                               const std::string &object_name,
                               const std::string &input_file, const allow_overwrite,
                               const Checksum *checksum) = 0;

  virtual void delete_object(const std::string &namespace_,
                             const std::string &object_name, const may_not_exist) = 0;

  virtual std::tuple<uint64_t, Checksum *>
  get_object_info(const std::string &namespace_, const std::string &object_name,
                  const consistent_read, const should_cache) = 0;

  virtual void read_objects_slices(const std::string &namespace_,
                                   const std::vector<proxy_protocol::ObjectSlices> &,
                                   const consistent_read) = 0;

  /* invalidate_cache influences the result of read requests issued with
   * consistent_read::F. after an invalidate cache request these read
   * requests will be at least consistent up to the point when the
   * invalidate_cache request was processed by the proxy. */
  virtual void invalidate_cache(const std::string &namespace_) = 0;
  /* drop_cache is a hint towards the proxy that this client will (at least for
   * a while) issue no more request to this proxy for this namespace. The proxy
   * uses this hint to prefer evicting items from its caches that belong to
   * this namespace.  */
  virtual void drop_cache(const std::string &namespace_) = 0;

  /* retrieve (major,minor,patch, hash) from the remote proxy
   */
  virtual std::tuple<int32_t, int32_t, int32_t, std::string> get_proxy_version() = 0;

  /* tell the proxy server to send its timestamp after a server side delay.
   * (this allows timeout tests)
   */
  virtual double ping(const double delay) = 0;
  virtual ~Proxy_client() {};
 };

 enum class Transport { tcp, rdma };

 std::ostream&
 operator<<(std::ostream&,
            Transport);

 std::istream&
 operator>>(std::istream&,
            Transport&);

 std::unique_ptr<Proxy_client>
   make_proxy_client(const std::string &ip,
                     const std::string &port,
                     const boost::asio::time_traits<
                     boost::posix_time::ptime>::duration_type &expiry_time,
                     const Transport &transport);


class TCPProxy_client : public Proxy_client {
public:
  TCPProxy_client(const std::string &ip, const std::string &port,
                  const boost::asio::time_traits<
                  boost::posix_time::ptime>::duration_type &expiry_time);

  std::tuple<std::vector<std::string>, has_more>
  list_namespaces(const std::string &first, const include_first,
                  const boost::optional<std::string> &last, const include_last,
                  const int max, const reverse reverse = reverse::F);
  bool namespace_exists(const std::string &name);
  void create_namespace(const std::string &name,
                        const boost::optional<std::string> &preset_name);
  void delete_namespace(const std::string &name);

  std::tuple<std::vector<std::string>, has_more>
  list_objects(const std::string &namespace_, const std::string &first,
               const include_first, const boost::optional<std::string> &last,
               const include_last, const int max,
               const reverse reverse = reverse::F);
  void read_object_fs(const std::string &namespace_,
                      const std::string &object_name,
                      const std::string &dest_file, const consistent_read,
                      const should_cache);
  void write_object_fs(const std::string &namespace_,
                       const std::string &object_name,
                       const std::string &input_file, const allow_overwrite,
                       const Checksum *checksum);
  void delete_object(const std::string &namespace_,
                     const std::string &object_name, const may_not_exist);
  std::tuple<uint64_t, Checksum *>
  get_object_info(const std::string &namespace_, const std::string &object_name,
                  const consistent_read, const should_cache);

  void read_objects_slices(const std::string &namespace_,
                           const std::vector<proxy_protocol::ObjectSlices> &,
                           const consistent_read);

  void invalidate_cache(const std::string &namespace_);

  void drop_cache(const std::string &namespace_);

  std::tuple<int32_t, int32_t, int32_t, std::string> get_proxy_version();

  double ping(const double delay);
private:
  void check_status(const char *function_name);

  boost::asio::ip::tcp::iostream _stream;
  proxy_protocol::Status _status;
  const boost::asio::time_traits<boost::posix_time::ptime>::duration_type
      _expiry_time;
};

class RDMAProxy_client : public Proxy_client{
public:
  RDMAProxy_client(const std::string &ip, const std::string &port,
                   const boost::asio::time_traits<
                   boost::posix_time::ptime>::duration_type &expiry_time);

  std::tuple<std::vector<std::string>, has_more>
    list_namespaces(const std::string &first, const include_first,
                    const boost::optional<std::string> &last, const include_last,
                    const int max, const reverse reverse = reverse::F);
  bool namespace_exists(const std::string &name);
  void create_namespace(const std::string &name,
                        const boost::optional<std::string> &preset_name);
  void delete_namespace(const std::string &name);

  std::tuple<std::vector<std::string>, has_more>
  list_objects(const std::string &namespace_, const std::string &first,
               const include_first, const boost::optional<std::string> &last,
               const include_last, const int max,
               const reverse reverse = reverse::F);

  void read_object_fs(const std::string &namespace_,
                      const std::string &object_name,
                      const std::string &dest_file, const consistent_read,
                      const should_cache);

  void write_object_fs(const std::string &namespace_,
                       const std::string &object_name,
                       const std::string &input_file, const allow_overwrite,
                       const Checksum *checksum);

  void delete_object(const std::string &namespace_,
                     const std::string &object_name, const may_not_exist);

  std::tuple<uint64_t, Checksum *>
  get_object_info(const std::string &namespace_, const std::string &object_name,
                  const consistent_read, const should_cache);

  void read_objects_slices(const std::string &namespace_,
                           const std::vector<proxy_protocol::ObjectSlices> &,
                           const consistent_read);

  void invalidate_cache(const std::string &namespace_);

  void drop_cache(const std::string &namespace_);
  std::tuple<int32_t, int32_t, int32_t, std::string> get_proxy_version();
  double ping(const double delay);
  ~RDMAProxy_client();
private:
  int _socket;
  void _really_write(const char * buf, int len);
  void _really_read (char * buf, int len);
  void check_status(const char *function_name);
  proxy_protocol::Status _status;
  std::function<void (const char* , const int)> _writer;
  std::function<void (char* , const int)> _reader;
  const boost::asio::time_traits<boost::posix_time::ptime>::duration_type
    _expiry_time;
  void _expires_from_now(const boost::asio::time_traits<
                         boost::posix_time::ptime>::duration_type &expiry_time);
  int _request_time_left; /* ms */
};


}
}

#endif
