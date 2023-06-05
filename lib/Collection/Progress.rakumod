use v6.d;
use Terminal::Spinners;
unit module Collection::Progress;
=begin pod
=head1 Description

Intended to be called first with a list of items that will be processed,
then called with C<:dec> when an item is processed.
The terminal then shows a bar indicating progress and the current file.
When all items are processed, the output shows the time spent processing
all items.
The optional header indicates what is being processed.

=head1 Usage

    counter(:start(52), :header<Processing all the weeks>);

A fixed number of items is processed. This is typically called at the start of a loop.

    counter(:items( @list-of-weekly-visits ), :header<Who visited> );

The items are strings that are printed when processed. Alternative set up call.

Later (typically in a loop processing each item)

    counter(:dec)

=end pod

#| uses Terminal::Spinners to create a progress bar, with items, showing next item with :dec
multi sub counter( Int :$start, |c ) is export { counter(:items( 'item: ' <<~>> (1 .. $start) ), |c) }
multi sub counter( :@items, :$dec = False, :$header) is export {
    my $beg = "\e[2K";
    my $ret = "\e[0G";
    state $hash-bar = Bar.new(:type<bar>, :79length );
    state $inc;
    state $done;
    state $timer;
    state $title = 'Caching files ';
    state $item = -1;
    state @s-items;
    $title = $_.Str with $header;
    @s-items = @items if +@items;
    if $dec and not +@items {
        $done += $inc;
    }
    else {
        $inc = 1 / @s-items.elems * 100;
        $done = 0;
        $timer = now;
        $item = -1;
        say $title;
    }
    my $bar = $hash-bar.show: $done, :nop;
    if ++$item >= +@s-items {
        my $d = (now - $timer).Int;
        my @t = $d div 3600 , ;
        @t[1] = ($d - @t[0] * 3600) div 60;
        @t[2] = $d - @t[0] * 3600 - @t[1] * 60;
        my $ts = @t[0] > 0 ?? sprintf("%dh:%dm:%ds", @t) !! sprintf("%dm:%ds",@t[1,2]) ;
        say $beg ~ "$bar\nCompleted in $ts";
        return
    }
    my $len = @s-items[$item].chars;
    my $name = $len > 45 ?? @s-items[$item].substr(*-45,*) !! @s-items[$item];
    print $beg ~ $bar ~ $name ~ $ret;
}

