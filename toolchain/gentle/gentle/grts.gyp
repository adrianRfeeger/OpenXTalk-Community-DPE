{
	'includes':
	[
		'../../../common.gypi',
	],
	
	'targets':
	[
		{
			'target_name': 'grts',
			'type': 'static_library',
			
			'toolsets': ['host','target'],
			
			'product_name': 'grts',
		
			'variables':
			{
				'silence_warnings': 1,
			},
			
			'xcode_settings':
			{
				'OTHER_CFLAGS':
				[
					'-Wno-implicit-int',
					'-Wno-implicit-function-declaration',
				],
			},
	
			'sources':
			[
				'grts.c',
			],
			
			'target_conditions':
			[
				[
					'_toolset != "target"',
					{
						'product_name': 'grts->(_toolset)',
					},
				],
			],
		},
	],
}
