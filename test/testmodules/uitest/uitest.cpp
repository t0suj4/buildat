#include "core/log.h"
#include "interface/module.h"
#include "interface/server.h"
#include "interface/event.h"
#include "network/api.h"
#include "client_file/api.h"

using interface::Event;

namespace uitest {

struct Module: public interface::Module
{
	interface::Server *m_server;

	Module(interface::Server *server):
		interface::Module("uitest"),
		m_server(server)
	{
		log_v(MODULE, "uitest construct");
	}

	~Module()
	{
		log_v(MODULE, "uitest destruct");
	}

	void init()
	{
		log_v(MODULE, "uitest init");
		m_server->sub_event(this, Event::t("core:start"));
		m_server->sub_event(this, Event::t("network:new_client"));
		m_server->sub_event(this, Event::t("client_file:files_transmitted"));
	}

	void event(const Event::Type &type, const Event::Private *p)
	{
		EVENT_VOIDN("core:start", on_start)
		EVENT_TYPEN("network:new_client", on_new_client, network::NewClient)
		EVENT_TYPEN("client_file:files_transmitted", on_files_transmitted,
				client_file::FilesTransmitted)
	}

	void on_start()
	{
	}

	void on_new_client(const network::NewClient &new_client)
	{
		log_i(MODULE, "uitest::on_new_client: id=%zu", new_client.info.id);
	}

	void on_files_transmitted(const client_file::FilesTransmitted &event)
	{
		log_v(MODULE, "on_files_transmitted(): recipient=%zu", event.recipient);

		network::access(m_server, [&](network::Interface * inetwork){
			inetwork->send(event.recipient, "core:run_script",
					"buildat.run_script_file(\"uitest/init.lua\")");
		});
	}
};

extern "C" {
	EXPORT void* createModule_uitest(interface::Server *server){
		return (void*)(new Module(server));
	}
}
}
// vim: set noet ts=4 sw=4:
