#pragma once
#include "core/types.h"

namespace interface
{
}

namespace client
{
	struct State
	{
		virtual ~State(){}
		virtual bool connect(const ss_ &address, const ss_ &port) = 0;
	};

	State* createState();
}
