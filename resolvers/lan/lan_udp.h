#ifndef __RS_LAN_UDP_DL_H__
#define __RS_LAN_UDP_DL_H__

#include "playdar/playdar_plugin_include.h"
#include "json_spirit/json_spirit.h"
#include <boost/asio.hpp>
#include <boost/bind.hpp>
#include <boost/regex.hpp>
#include <boost/foreach.hpp>
#include <boost/asio.hpp>
#include <iostream>
#include <map>
#include <string>


/*
    Broadcast search queries on the LAN using UDP multicast
    Works by sending JSON-serialized ResolverQuery objects.
    
    Responses come in via UDP, and we stream songs using HTTP.
*/

namespace playdar {
namespace resolvers {

class lan_udp : public ResolverService
{
    public:
    lan_udp(){}
    
    void init(playdar::Config * c, Resolver * r);
    void run();
    void start_resolving(boost::shared_ptr<ResolverQuery> rq);
    std::string name() const { return "LAN/UDP"; }
    
    void handle_receive_from(const boost::system::error_code& error, size_t bytes_recvd);
    void start_listening(boost::asio::io_service& io_service,
        const boost::asio::ip::address& listen_address,
        const boost::asio::ip::address& multicast_address,
        const short multicast_port);
    
    void send_response( query_uid qid, 
                        boost::shared_ptr<PlayableItem> pip,
                        boost::asio::ip::udp::endpoint sep );
    
    /// max time in milliseconds we'd expect to have results in.
    unsigned int target_time() const
    {
        return 50;
    }
    
    /// highest weighted resolverservices are queried first.
    unsigned short weight() const
    {
        return 99;
    }
                        
protected:    
    ~lan_udp() throw();
    
private:
    boost::asio::io_service * m_io_service;
    boost::thread * m_responder_thread;
    void handle_send(   const boost::system::error_code& error,
                                size_t bytes_recvd,
                                char * scratch );

    void async_send(boost::asio::ip::udp::endpoint * remote_endpoint,
                    string message);

    boost::asio::ip::udp::socket * socket_;
    boost::asio::ip::udp::endpoint sender_endpoint_;
    boost::asio::ip::udp::endpoint * broadcast_endpoint_;
    enum { max_length = 1024 };
    char data_[max_length];
};

EXPORT_DYNAMIC_CLASS( lan_udp )


}}
#endif