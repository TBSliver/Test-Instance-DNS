# NAME

Test::Instance::DNS - Mock DNS server for testing

# SYNOPSIS

    use Test::More;
    use Test::DNS;
    use Test::Instance::DNS;

    my $t_i_dns = Test::Instance::DNS->new(
      listen_addr => '127.0.0.1',
      zone_file => 't/etc/db.example.com',
    );

    $t_i_dns->run;

    my $dns = Test::DNS->new(nameservers => ['127.0.0.1']);
    $dns->object->port($t_i_dns->listen_port);

    $dns->is_a('example.com' => '192.0.2.1');

    done_testing;

# DESCRIPTION

Provides a local mock DNS server usable for testing.

# AUTHOR

Tom Bloor <t.bloor@shadowcat.co.uk>

# COPYRIGHT

Copyright 2018- Tom Bloor

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[Test::DNS](https://metacpan.org/pod/Test::DNS) [Net::DNS](https://metacpan.org/pod/Net::DNS)
