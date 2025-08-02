package dev.java;

import java.util.List;
import java.util.TimeZone;

public class Sandbox {

    static void main() {
        TimeZone.getDefault().getID();
        System.out.println(TimeZone.getDefault().getID());
        System.out.println(2 + 2);
        List.of(1, 2, 3).stream().map(x -> x + 1).toList();
        increment(List.of(1, 2, 3));
    }

    static List<Integer> increment(List<Integer> list) {
        return list.stream().map(n -> n + 1).toList();
    }

}
